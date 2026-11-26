#!/usr/bin/env python3
"""Prepare public media corpus samples (materials/playback/public/manifest.json)
for the package-media integration test runner (integration_test/formats_test.dart).

Usage:
  prepare_public_corpus.py --out FILE [--corpus DIR] [--source ID[,ID...]] [--only GLOB[,GLOB...]]
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
RAW_ELEMENTARY_EXTS = {"vc1", "dts", "thd", "pva", "shn", "amr", "awb", "nsv", "nuv", "viv", "dvr-ms", "m2v", "adp", "act", "dvf", "msv", "ac3", "eac3", "ivf", "aea", "qcp", "qoa", "ts", "iamf", "ra", "rm", "rmhd", "bik", "smk", "bcstm", "brstm", "ast", "oma", "aa3", "vqf", "xwma"}
UNRELIABLE_DURATION_EXTS = RAW_ELEMENTARY_EXTS | {"wmv", "asf"}
TRACKER_EXTS = {"mod", "xm", "it", "s3m", "med", "669", "amf", "dmf", "far", "gdm", "imf", "mtm", "okt", "sfx", "stm", "ult"}
STANDALONE_SUBTITLE_EXTS = {"idx", "sub", "sup", "srt", "ass", "vtt"}


def file_ext(filename: str) -> str:
    if filename.startswith("OKT."):
        return "okt"
    if filename.startswith("SFX."):
        return "sfx"
    return pathlib.Path(filename).suffix.lstrip(".").lower()


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def sample_id(source_id: str, filename: str) -> str:
    ext = file_ext(filename)
    stem = filename[4:] if filename.startswith(("OKT.", "SFX.")) else pathlib.Path(filename).stem
    safe_stem = re.sub(r"[^A-Za-z0-9_.-]+", "_", stem).strip("_")
    return f"public-{source_id}-{safe_stem}-{ext}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=pathlib.Path, default=ROOT.parent / "materials/playback/public")
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--source", default="", help="comma-separated source_ids")
    ap.add_argument("--only", default="", help="comma-separated sample id globs")
    args = ap.parse_args()

    corpus = args.corpus.resolve()
    manifest_path = corpus / "manifest.json"
    if not manifest_path.is_file():
        print(f"manifest not found: {manifest_path} (run materials/playback/fetch_public_corpus.py first)", file=sys.stderr)
        return 2

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    wanted_sources = {s.strip() for s in args.source.split(",") if s.strip()}
    patterns = [p.strip() for p in args.only.split(",") if p.strip()]

    samples: list[dict] = []
    for src in manifest.get("sources", []):
        sid = src["source_id"]
        if wanted_sources and sid not in wanted_sources:
            continue
        for item in src.get("files", []):
            fname = item["filename"]
            sid_name = sample_id(sid, fname)
            if patterns and not any(fnmatch.fnmatch(sid_name, pat) for pat in patterns):
                continue
            ext = file_ext(fname)
            if ext in STANDALONE_SUBTITLE_EXTS:
                continue
            path = corpus / item["relpath"]
            entry: dict = {
                "id": sid_name,
                "source": sid,
                "ext": ext,
                "linear": item.get("linear", ["ALL-370"]),
                "note": f"[{sid}] {item.get('note', fname)}",
            }
            if not path.is_file():
                entry.update(status="error", error=f"missing file: {path}")
                samples.append(entry)
                continue
            digest = sha256_file(path)
            if item.get("sha256") and digest != item["sha256"]:
                entry.update(status="error", error=f"sha256 mismatch for {item['relpath']}")
                samples.append(entry)
                continue

            pr = item.get("probe") or {}
            # Tracker modules may not be readable by host ffprobe without libopenmpt,
            # but libmpv/libVLC can still decode them as audio-only streams.
            if not pr.get("ok") and ext in TRACKER_EXTS:
                probe_info = {
                    "container": ext,
                    "duration_ms": 0,
                    "video_codec": None,
                    "pix_fmt": None,
                    "width": None,
                    "height": None,
                    "sar": None,
                    "audio_codec": ext,
                    "channels": None,
                    "sample_rate": None,
                }
            elif not pr.get("ok"):
                entry.update(status="error", error=pr.get("error", "ffprobe failed"))
                samples.append(entry)
                continue
            else:
                probe_info = {
                    "container": pr.get("format_name"),
                    "duration_ms": pr.get("duration_ms") or 0,
                    "video_codec": pr.get("video_codec"),
                    "pix_fmt": pr.get("pix_fmt"),
                    "width": pr.get("width"),
                    "height": pr.get("height"),
                    "sar": pr.get("sar"),
                    "audio_codec": pr.get("audio_codec"),
                    "channels": pr.get("channels"),
                    "sample_rate": pr.get("sample_rate"),
                }

            dur_ms = probe_info["duration_ms"] or 0
            want_video = bool(probe_info["video_codec"])
            want_audio = bool(probe_info["audio_codec"])
            if not want_video and not want_audio:
                # Subtitle-only files cannot be played standalone.
                continue

            truncated = item.get("seekable") is False
            expect = {
                "video": want_video,
                "audio": want_audio,
                "seek": (not truncated) and (dur_ms >= 3000) and (ext not in RAW_ELEMENTARY_EXTS),
                "duration_ms": None if (truncated or ext in UNRELIABLE_DURATION_EXTS or dur_ms <= 0) else dur_ms,
                "play_to_end": (not truncated) and (0 < dur_ms <= 20000) and (ext not in RAW_ELEMENTARY_EXTS),
                "frame": None,
                "tone_hz": None,
            }
            if sid == "matroska-test-files" and fname == "test5.mkv":
                # Matroska conformance Wave 1 test5: 2 audio tracks + 7+ subtitle tracks.
                expect["min_audio_tracks"] = 2
                expect["min_subtitle_tracks"] = 7
            entry.update(
                status="ok",
                path=str(path),
                sha256=digest,
                bytes=path.stat().st_size,
                probe=probe_info,
                expect=expect,
            )
            samples.append(entry)

    if not samples:
        print("no public corpus samples selected", file=sys.stderr)
        return 2

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"samples": samples}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"prepared {len(samples)} public corpus sample(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
