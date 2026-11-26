#!/usr/bin/env python3
"""Prepare typical .iso disc image samples (DVD-Video ISO, Blu-ray BDMV ISO,
and public Kodi Wiki 3DLR-patterns.iso) for package-media playback tests (ALL-210).
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--iso-dir", type=pathlib.Path, default=ROOT.parent / "materials/playback/public/iso-samples")
    ap.add_argument("--out", type=pathlib.Path, required=True)
    args = ap.parse_args()

    iso_dir = args.iso_dir.resolve()
    cases = [
        {
            "id": "iso-dvd-video",
            "path": iso_dir / "dvd-video.iso",
            "note": "Unencrypted PAL 16:9 DVD-Video ISO (VIDEO_TS, MPEG-2 + AC3)",
            "video": True,
            "audio": True,
            "width": 720,
            "height": 576,
            "sar": "64:45",
            "duration_ms": 8000,
            "seek": True,
        },
        {
            "id": "iso-bluray-bdmv",
            "path": iso_dir / "bluray-bdmv.iso",
            "note": "Unencrypted Blu-ray BDMV ISO (UDF 2.50, H.264 + AC3)",
            "video": True,
            "audio": True,
            "width": 1280,
            "height": 720,
            "sar": "1:1",
            "duration_ms": 8000,
            "seek": True,
        },
        {
            "id": "iso-kodi-3dlr-patterns",
            "path": iso_dir / "3DLR-patterns.iso",
            "note": "Public Kodi Wiki Blu-ray/AVCHD 3DLR-patterns.iso (hometheaterphotos.com)",
            "video": True,
            "audio": False,
            "width": 1920,
            "height": 1080,
            "sar": "1:1",
            "duration_ms": None,
            "seek": True,
        },
    ]

    samples = []
    for c in cases:
        p: pathlib.Path = c["path"]
        if not p.is_file():
            samples.append({
                "id": c["id"], "ext": "iso", "linear": ["ALL-210"], "note": c["note"],
                "status": "error", "error": f"missing {p}",
            })
            continue
        samples.append({
            "id": c["id"],
            "ext": "iso",
            "linear": ["ALL-210"],
            "note": c["note"],
            "status": "ok",
            "path": str(p),
            "sha256": sha256_file(p),
            "bytes": p.stat().st_size,
            "probe": {
                "container": "iso",
                "duration_ms": c["duration_ms"] or 0,
                "video_codec": "disc",
                "pix_fmt": None,
                "width": c["width"],
                "height": c["height"],
                "sar": c["sar"],
                "audio_codec": "disc" if c["audio"] else None,
                "channels": 2 if c["audio"] else None,
                "sample_rate": 48000 if c["audio"] else None,
            },
            "expect": {
                "video": c["video"],
                "audio": c["audio"],
                "seek": c["seek"],
                "duration_ms": c["duration_ms"],
                "play_to_end": bool(c["duration_ms"] and c["duration_ms"] <= 20000),
                "frame": None,
                "tone_hz": None,
            },
        })

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"samples": samples}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"prepared {len(samples)} ISO sample(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
