"""Serve registered material files and stage local-only Android inputs."""
from __future__ import annotations

import copy
import hashlib
import http.server
import pathlib
import re
import shutil
import subprocess
import threading
import urllib.parse

from serve_samples import RangeHandler


class AndroidMaterials:
    def __init__(self, device: str, adb: str | None = None):
        self.device = device
        self.adb = adb or shutil.which("adb") or str(
            pathlib.Path.home() / "Library/Android/sdk/platform-tools/adb")
        self.files = {}
        owner = self

        class Handler(RangeHandler):
            def translate_path(self, path):
                route = urllib.parse.unquote(urllib.parse.urlsplit(path).path)
                return str(owner.files.get(route, pathlib.Path("/__opx_unregistered_asset__")))

            def list_directory(self, path):
                self.send_error(404)
                return None

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.port = self.server.server_port
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)

    def __enter__(self):
        try:
            subprocess.run([self.adb, "-s", self.device, "reverse",
                            f"tcp:{self.port}", f"tcp:{self.port}"], check=True, capture_output=True)
        except BaseException:
            self.server.server_close()
            raise
        self.thread.start()
        return self

    def __exit__(self, *exception):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
        subprocess.run([self.adb, "-s", self.device, "reverse", "--remove", f"tcp:{self.port}"],
                       capture_output=True)

    def url(self, path: pathlib.Path) -> str:
        path = path.resolve()
        parent = hashlib.sha256(str(path.parent).encode()).hexdigest()[:24]
        route = f"/asset/{parent}/{path.name}"
        self.files[route] = path
        return f"http://127.0.0.1:{self.port}{urllib.parse.quote(route)}"

    @staticmethod
    def local_path(value: str) -> tuple[pathlib.Path, str]:
        parsed = urllib.parse.urlsplit(value)
        if parsed.scheme in {"file", "dvd", "bluray"}:
            return pathlib.Path(urllib.parse.unquote(parsed.path)), parsed.scheme
        if parsed.scheme:
            raise ValueError(f"not a local material: {value}")
        return pathlib.Path(value), ""

    def sample(self, original: dict, folder: pathlib.Path) -> dict:
        sample = copy.deepcopy(original)
        path, scheme = self.local_path(sample["path"])
        original_path = path
        path = path.resolve()
        device_files = []
        local_names = {}

        def stage(file, relative=None):
            file = pathlib.Path(file).resolve()
            if not file.is_file():
                raise FileNotFoundError(file)
            name = relative or f"files/{hashlib.sha256(str(file.parent).encode()).hexdigest()[:16]}/{file.name}"
            device_files.append({"url": self.url(file), "name": name})
            local_names[str(file)] = name
            return "OPX_LOCAL/" + name

        ext = sample["ext"]
        if scheme in {"dvd", "bluray"} or ext == "ifo":
            directory = path if path.is_dir() else path.parent
            for file in sorted(directory.rglob("*")):
                if file.is_file():
                    stage(file, "disc/" + file.relative_to(directory).as_posix())
            location = "OPX_LOCAL/disc" + ("/" + path.name if path.is_file() else "")
            sample["path"] = f"{scheme}://{location}" if scheme in {"dvd", "bluray"} else location
        elif ext == "001":
            prefix = path.name[:-3]
            for file in sorted(path.parent.glob(prefix + "[0-9][0-9][0-9]")):
                stage(file, "split/" + file.name)
            sample["path"] = "OPX_LOCAL/" + local_names[str(path)]
        elif ext in {"iso", "img", "nrg", "bin", "mogg", "vox"}:
            sample["path"] = stage(path)
        elif ext in {"asx", "strm", "pls", "m3u", "cue"}:
            # Preserve sibling target names for CUE, and replace host file
            # paths/URIs in pointer files by explicit URLs registered below.
            text = path.read_text()
            for uri in set(re.findall(r"file://[^\s\"'<>]+", text)):
                target_file = pathlib.Path(urllib.parse.unquote(urllib.parse.urlsplit(uri).path))
                if not target_file.is_file():
                    raise FileNotFoundError(target_file)
                text = text.replace(uri, self.url(target_file))
            for line in text.splitlines():
                candidate = line.strip()
                if candidate.lower().startswith("file") and "=" in candidate:
                    candidate = candidate.split("=", 1)[1].strip()
                if candidate.startswith("/") and pathlib.Path(candidate).is_file():
                    text = text.replace(candidate, self.url(pathlib.Path(candidate)))
            for sibling in original_path.parent.iterdir():
                if sibling.is_file() and sibling.resolve() != path:
                    target = self.url(sibling)
                    for spelling in {sibling.absolute(), sibling.resolve()}:
                        text = text.replace(spelling.as_uri(), target).replace(str(spelling), target)
            folder.mkdir(parents=True, exist_ok=True)
            rewritten = folder / path.name
            rewritten.write_text(text)
            self.url(rewritten)
            # Relative playlist entries must still resolve to the original
            # siblings, so publish the rewritten text at the original route.
            route = urllib.parse.unquote(urllib.parse.urlsplit(self.url(path)).path)
            self.files[route] = rewritten
            if ext in {"asx", "strm"}:
                name = f"pointers/{path.name}"
                device_files.append({"url": self.url(path), "name": name})
                self.files[route] = rewritten
                sample["path"] = "OPX_LOCAL/" + name
            else:
                sample["path"] = self.url(path)
                self.files[route] = rewritten
        else:
            sample["path"] = self.url(path)
        expectations = sample.get("expect", {})
        if expectations.get("frame"):
            expectations["frame"] = self.url(pathlib.Path(expectations["frame"]))
        if expectations.get("external_subtitle"):
            subtitle = pathlib.Path(expectations["external_subtitle"])
            expectations["external_subtitle"] = stage(subtitle, "subtitles/" + subtitle.name)
            for sibling in subtitle.parent.glob(subtitle.stem + ".*"):
                if sibling != subtitle and sibling.suffix.lower() in {".idx", ".sub"}:
                    stage(sibling, "subtitles/" + sibling.name)
        if device_files:
            sample["device_files"] = device_files
        return sample
