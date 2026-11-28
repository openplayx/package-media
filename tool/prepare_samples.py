#!/usr/bin/env python3
"""Prepare the file format samples listed in formats/manifest.json.

Generated samples are encoded locally with ffmpeg from SMPTE bars and a 1 kHz
tone (both deterministic, so they carry no licensing questions); downloaded
samples must match their sha256; playlist samples are text files pointing at
another prepared sample. Every result is checked with ffprobe (the real
container/codecs, not the extension) and written to a resolved list that the
integration test (example/integration_test/formats_test.dart) reads.

With --pack DIR, the local media of the shared material pack
(materials/playback/, ALL-370) is added as samples "pack-<issue>-<ext>": expectations come
from ffprobe; the pack's synthetic audio is a 440 Hz tone and its moving test
pattern has no reference frame. Subtitle-only files and external candidates
are left out. External candidates (real files from public test suites such
as the FFmpeg FATE suite) join as "ext-<issue>-<ext>" only once an operator
has downloaded them with the pack's fetch_samples.py (it asks for a license
review first), or by hand, into the pack's external/<issue>/; each is copied under the
issue's extension, since its own name may use another suffix (MPP and MP+ use
an .mpc file). Their content is unknown: no tone or frame check.

Usage: prepare_samples.py --cache DIR --out FILE [--only ID[,ID...]] [--pack DIR]
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "formats" / "manifest.json"
SECONDS = 6
FPS = 25
TONE_HZ = 1000
DEFAULT_SIZE = "320x240"
# Reference frames and snapshots are compared on this grid (box-averaged).
GRID = (32, 24)
MAX_DOWNLOAD = 200 * 1024 * 1024


def run(cmd: list[str]) -> str:
    p = subprocess.run(cmd, capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"{cmd[0]} failed: {p.stderr.strip()[-600:]}")
    return p.stdout


def sha256(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def generate(sample: dict, dest: pathlib.Path) -> None:
    size = sample.get("size", DEFAULT_SIZE)
    args = sample["generate"]
    inputs: list[str] = []
    maps: list[str] = []
    if not sample.get("audio_only"):
        inputs += ["-f", "lavfi", "-i", f"smptebars=size={size}:rate={FPS}:duration={SECONDS}"]
        maps += ["-map", f"{len(maps) // 2}:v"]
    if not sample.get("video_only"):
        inputs += ["-f", "lavfi", "-i", f"sine=frequency={TONE_HZ}:sample_rate=48000:duration={SECONDS}"]
        maps += ["-map", f"{len(maps) // 2}:a"]
        if "-ac" not in args:
            args = ["-ac", "2", *args]
    spec = json.dumps([inputs, maps, args])
    stamp = dest.with_name(dest.name + ".spec")
    if dest.exists() and stamp.exists() and stamp.read_text() == spec:
        return
    # Keep the extension last: ffmpeg picks the muxer from it.
    tmp = dest.with_name(f"{dest.stem}.part{dest.suffix}")
    tmp.unlink(missing_ok=True)
    run(["ffmpeg", "-nostdin", "-v", "error", "-y", *inputs, *maps, "-t", str(SECONDS), *args, str(tmp)])
    tmp.replace(dest)
    stamp.write_text(spec)


def download(sample: dict, dest: pathlib.Path) -> None:
    if dest.exists() and sha256(dest) == sample["sha256"]:
        return
    tmp = dest.with_name(dest.name + ".part")
    last: Exception | None = None
    for _ in range(3):
        try:
            with urllib.request.urlopen(sample["url"], timeout=60) as r, tmp.open("wb") as f:
                total = 0
                while chunk := r.read(1 << 20):
                    total += len(chunk)
                    if total > MAX_DOWNLOAD:
                        raise RuntimeError("download exceeds size limit")
                    f.write(chunk)
            break
        except Exception as e:  # retried below
            last = e
    else:
        raise RuntimeError(f"download failed: {last}")
    got = sha256(tmp)
    if got != sample["sha256"]:
        tmp.unlink()
        raise RuntimeError(f"sha256 mismatch: {got}")
    tmp.replace(dest)


def playlist(sample: dict, target: pathlib.Path, dest: pathlib.Path) -> None:
    uri = target.as_uri()
    text = {
        "pls": f"[playlist]\nFile1={uri}\nTitle1={target.stem}\nLength1=-1\nNumberOfEntries=1\nVersion=2\n",
        "m3u": f"#EXTM3U\n#EXTINF:-1,{target.stem}\n{target}\n",
        "asx": f'<asx version="3.0">\n  <entry>\n    <title>{target.stem}</title>\n    <ref href="{uri}"/>\n  </entry>\n</asx>\n',
        "cue": f'FILE "{target.name}" WAVE\n  TRACK 01 AUDIO\n    TITLE "{target.stem}"\n    INDEX 01 00:00:00\n',
    }[sample["ext"]]
    dest.write_text(text)


def probe(path: pathlib.Path) -> dict:
    data = json.loads(run(["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", str(path)]))
    video = next((s for s in data["streams"] if s.get("codec_type") == "video"), None)
    audio = next((s for s in data["streams"] if s.get("codec_type") == "audio"), None)
    duration = float(data["format"].get("duration") or (video or audio or {}).get("duration") or 0)
    return {
        "container": data["format"]["format_name"],
        "duration_ms": round(duration * 1000),
        "video_codec": video and video.get("codec_name", "unknown"),
        "pix_fmt": video and video.get("pix_fmt"),
        "width": video and video["width"],
        "height": video and video["height"],
        "sar": video and video.get("sample_aspect_ratio"),
        "audio_codec": audio and audio.get("codec_name", "unknown"),
        "channels": audio and audio.get("channels"),
        "sample_rate": audio and int(audio.get("sample_rate", 0)),
    }


def reference(size: str, refs: pathlib.Path) -> pathlib.Path:
    path = refs / f"smptebars-{size}-{GRID[0]}x{GRID[1]}.rgb"
    if not path.exists():
        run(["ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", f"smptebars=size={size}:rate={FPS}",
             "-frames:v", "1", "-vf", f"scale={GRID[0]}:{GRID[1]}:flags=area", "-pix_fmt", "rgb24",
             "-f", "rawvideo", str(path)])
    return path


PACK_TONE_HZ = 440
# Pack files whose audio is not the 440 Hz sine (the MOD tone is set by its
# note period).
PACK_NO_TONE = {"fixtures/audio/tone.mod"}
PACK_URL = "http://127.0.0.1:8765/fixtures/"


def pack_samples(pack: pathlib.Path) -> list[dict]:
    """One sample per local pack file (issues sharing a file are merged)."""
    by_path: dict[str, dict] = {}
    for t in json.loads((pack / "manifest.json").read_text())["tasks"]:
        if t["status"] not in ("local_media", "local_reference"):
            continue
        streams = {st["codec_type"] for st in (t.get("probe") or {}).get("streams", [])}
        if t["status"] == "local_media" and not streams & {"video", "audio"}:
            continue  # standalone subtitles: no playback test of their own
        s = by_path.get(t["path"])
        if s:
            s["linear"].append(t["issue"])
            continue
        ext = pathlib.Path(t["path"]).suffix.lstrip(".").lower()
        by_path[t["path"]] = {"id": f"pack-{t['issue'].lower()}-{ext}", "ext": ext, "linear": [t["issue"]],
                              "pack": t["path"], "sha256": t["sha256"], "note": t["format"],
                              "pack_probe": t.get("probe")}
    return list(by_path.values())


def external_samples(pack: pathlib.Path) -> list[dict]:
    """One sample per downloaded external candidate of an extension issue."""
    samples = []
    for t in json.loads((pack / "manifest.json").read_text())["tasks"]:
        folder = pack / "external" / t["issue"]
        if not t["category"].endswith("_extension") or not folder.is_dir():
            continue
        urls = {f["filename"]: f["url"] for f in t.get("files", [])}
        files = sorted(f for f in folder.iterdir() if f.is_file() and not f.name.startswith("."))
        if files:
            ext = t["format"].lower()
            src = files[0]
            samples.append({"id": f"ext-{t['issue'].lower()}-{ext}", "ext": ext, "linear": [t["issue"]],
                            "external": str(src), "note": f"{t['format']}: {urls.get(src.name, src.name)}"})
            # This FATE APE has only 3.34 s of data but declares 60.48 s.
            # Match its bytes so a replacement MAC sample still tests seeking.
            if (src.name == "luckynight-mac394b1-c2000.ape"
                    and sha256(src) == "c17918e48df298a648bc3efa23e948bcd055af8cc2a631af183b10e6a198c1bc"):
                samples[-1]["expect"] = {"seek": False, "duration_ms": None,
                                          "play_to_end": False}
    return samples


def unprobed(path: pathlib.Path) -> dict:
    """probe() fields for an audio file the local ffprobe cannot read
    (tracker modules need libopenmpt): expect sound only."""
    return {"container": None, "duration_ms": 0, "video_codec": None, "pix_fmt": None, "width": None,
            "height": None, "sar": None, "audio_codec": "unknown", "channels": None, "sample_rate": None}


def from_pack_probe(data: dict) -> dict:
    """probe() fields from the pack's recorded ffprobe output, for files the
    local ffprobe cannot read (MOD needs libopenmpt)."""
    video = next((st for st in data["streams"] if st["codec_type"] == "video"), None)
    audio = next((st for st in data["streams"] if st["codec_type"] == "audio"), None)
    return {"container": data["format"]["format_name"],
            "duration_ms": round(float(data["format"].get("duration") or 0) * 1000),
            "video_codec": video and video.get("codec_name", "unknown"), "pix_fmt": video and video.get("pix_fmt"),
            "width": video and video.get("width"), "height": video and video.get("height"), "sar": None,
            "audio_codec": audio and audio.get("codec_name", "unknown"), "channels": None, "sample_rate": None}


def copy_pack(pack: pathlib.Path, media: pathlib.Path) -> pathlib.Path:
    """Copies the pack fixtures into the cache; references are rewritten from
    the pack's local HTTP server to file URIs of the copies."""
    dest = media / "pack"
    for src in (pack / "fixtures").rglob("*"):
        if not src.is_file():
            continue
        out = dest / src.relative_to(pack)
        out.parent.mkdir(parents=True, exist_ok=True)
        if src.parent.name == "reference" and src.suffix in (".pls", ".asx", ".strm"):
            out.write_text(src.read_text().replace(PACK_URL, (dest / "fixtures").as_uri() + "/"))
        elif not out.exists() or out.stat().st_size != src.stat().st_size:
            shutil.copyfile(src, out)
    return dest


def reference_target(path: pathlib.Path) -> pathlib.Path | None:
    """The media file a pack reference (pls, asx, strm, cue) points at."""
    text = path.read_text()
    if path.suffix == ".cue":
        return path.parent / text.split('"')[1]
    for token in text.replace('"', " ").replace("=", " ").split():
        if token.startswith("file://"):
            return pathlib.Path(urllib.request.url2pathname(token[len("file://"):]))
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", required=True, type=pathlib.Path)
    ap.add_argument("--out", required=True, type=pathlib.Path)
    ap.add_argument("--only", default="", help="comma-separated ids or glob patterns")
    ap.add_argument("--pack", type=pathlib.Path, help="format material pack (materials/playback)")
    a = ap.parse_args()
    for tool in ("ffmpeg", "ffprobe"):
        if not shutil.which(tool):
            print(f"{tool} is required (brew install ffmpeg)", file=sys.stderr)
            return 2
    samples = json.loads(MANIFEST.read_text())["samples"]
    if a.pack:
        if not (a.pack / "manifest.json").exists():
            print(f"no manifest.json in {a.pack}", file=sys.stderr)
            return 2
        samples += pack_samples(a.pack) + external_samples(a.pack)
    by_id = {s["id"]: s for s in samples}
    patterns = [p for p in a.only.split(",") if p]
    wanted = [s for s in samples if not patterns or any(fnmatch.fnmatch(s["id"], p) for p in patterns)]
    if not wanted:
        print(f"no sample matches {a.only!r}", file=sys.stderr)
        return 2
    media = a.cache / "media"
    refs = a.cache / "refs"
    media.mkdir(parents=True, exist_ok=True)
    refs.mkdir(parents=True, exist_ok=True)
    pack_copy = copy_pack(a.pack, media) if a.pack and any("pack" in s for s in wanted) else None

    def prepare(s: dict) -> tuple[pathlib.Path, dict]:
        if "pack" in s:
            if sha256(a.pack / s["pack"]) != s["sha256"]:
                raise RuntimeError(f"sha256 mismatch for {s['pack']}")
            dest = pack_copy / s["pack"]
            target = reference_target(dest) if dest.parent.name == "reference" else dest
            if target is None:
                raise RuntimeError(f"no media reference in {s['pack']}")
            try:
                return dest, probe(target)
            except RuntimeError:
                if target != dest or not s.get("pack_probe"):
                    raise
                return dest, from_pack_probe(s["pack_probe"])
        dest = media / f"{s['id']}.{s['ext']}"
        if "external" in s:
            shutil.copyfile(s["external"], dest)
            try:
                return dest, probe(dest)
            except RuntimeError:
                return dest, unprobed(dest)
        if "playlist" in s:
            target, info = prepare(by_id[s["playlist"]])
            playlist(s, target, dest)
            return dest, info
        if "generate" in s:
            generate(s, dest)
        else:
            download(s, dest)
        return dest, probe(dest)

    resolved = []
    for s in wanted:
        entry = {"id": s["id"], "ext": s["ext"], "linear": s.get("linear", []), "note": s.get("note")}
        try:
            path, info = prepare(s)
            target = by_id[s["playlist"]] if "playlist" in s else s
            pack_tone = "pack" in s and info["audio_codec"] and s["pack"] not in PACK_NO_TONE
            expect = {
                "video": bool(info["video_codec"]),
                "audio": bool(info["audio_codec"]),
                "seek": True,
                "frame": None,
                "tone_hz": TONE_HZ if "generate" in target and info["audio_codec"] else PACK_TONE_HZ if pack_tone else None,
                # Generated samples have a known length; ffprobe only estimates
                # raw elementary streams.
                "duration_ms": SECONDS * 1000 if "generate" in target else info["duration_ms"] or None,
            }
            if "generate" in target and info["video_codec"]:
                expect["frame"] = str(reference(target.get("size", DEFAULT_SIZE), refs))
            if "external" in s:
                # Real files: short ones cannot show a seek, long ones need
                # not be played to their end after it.
                expect["seek"] = not info["duration_ms"] or info["duration_ms"] >= 3000
                expect["play_to_end"] = 0 < info["duration_ms"] <= 20000
            expect.update(s.get("expect", {}))
            entry.update(status="ok", path=str(path), sha256=sha256(path), bytes=path.stat().st_size,
                         probe=info, expect=expect, grid=list(GRID))
        except Exception as e:
            entry.update(status="error", error=str(e))
        print(f"{entry['status']:5} {s['id']}" + (f"  {entry.get('error', '')}" if entry["status"] != "ok" else ""))
        resolved.append(entry)
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps({"samples": resolved}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
