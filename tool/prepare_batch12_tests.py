#!/usr/bin/env python3
"""Prepare Batch 1 (disc/entry/split: .img, .ifo, .nrg, .bin, .bivx, .001) and
Batch 2 (HD audio & GameCube ADPCM: DTS-HD MA, Dolby Atmos, DTS:X, .adp, .afc)
samples for package-media macOS playback integration tests.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def ffprobe_info(path: pathlib.Path) -> dict:
    out = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=format_name,duration:stream=codec_type,codec_name,width,height,sample_aspect_ratio,channels,sample_rate,pix_fmt",
            "-of",
            "json",
            str(path),
        ],
        text=True,
    )
    data = json.loads(out)
    fmt = data.get("format", {})
    streams = data.get("streams", [])
    v = next((s for s in streams if s.get("codec_type") == "video"), None)
    a = next((s for s in streams if s.get("codec_type") == "audio"), None)
    dur = float(fmt.get("duration") or 0)
    return {
        "container": fmt.get("format_name"),
        "duration_ms": int(round(dur * 1000)) if dur > 0 else 0,
        "video_codec": v.get("codec_name") if v else None,
        "pix_fmt": v.get("pix_fmt") if v else None,
        "width": v.get("width") if v else None,
        "height": v.get("height") if v else None,
        "sar": v.get("sample_aspect_ratio") if v else None,
        "audio_codec": a.get("codec_name") if a else None,
        "channels": a.get("channels") if a else None,
        "sample_rate": int(a["sample_rate"]) if a and a.get("sample_rate") else None,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--samples-dir",
        type=pathlib.Path,
        default=ROOT.parent / "materials/playback/public/batch12-samples",
    )
    ap.add_argument(
        "--batch2-dir",
        type=pathlib.Path,
        default=ROOT.parent / "materials/playback/public/batch2-samples",
    )
    ap.add_argument("--out", type=pathlib.Path, required=True)
    args = ap.parse_args()

    sdir = args.samples_dir.resolve()
    b2dir = args.batch2_dir.resolve()
    ifo_path = (ROOT.parent / "materials/playback/fixtures/advanced/dvd/VIDEO_TS/VIDEO_TS.IFO").resolve()

    disc_probe = {
        "container": "disc",
        "duration_ms": 8000,
        "video_codec": "disc",
        "pix_fmt": None,
        "width": 720,
        "height": 576,
        "sar": "64:45",
        "audio_codec": "disc",
        "channels": 2,
        "sample_rate": 48000,
    }

    cases = [
        # --- Batch 1 ---
        {
            "id": "disc-img-dvd",
            "ext": "img",
            "linear": ["ALL-211"],
            "path": sdir / "dvd-video.img",
            "note": "Unencrypted DVD-Video .img disc image",
            "probe": disc_probe,
            "expect": {
                "video": True, "audio": True, "seek": True,
                "duration_ms": 8000, "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "disc-ifo-dvd",
            "ext": "ifo",
            "linear": ["ALL-212"],
            "path": ifo_path,
            "note": "DVD-Video VIDEO_TS/VIDEO_TS.IFO entry",
            "probe": disc_probe,
            "expect": {
                "video": True, "audio": True, "seek": True,
                "duration_ms": 8000, "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "disc-nrg-dvd",
            "ext": "nrg",
            "linear": ["ALL-213"],
            "path": sdir / "dvd-video.nrg",
            "note": "Nero .nrg DVD-Video image (ISO9660+UDF + NER5 footer)",
            "probe": disc_probe,
            "expect": {
                "video": True, "audio": True, "seek": True,
                "duration_ms": 8000, "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "disc-bin-dvd",
            "ext": "bin",
            "linear": ["ALL-214"],
            "path": sdir / "dvd-video.bin",
            "note": "DVD-Video 2048-byte sector .bin disc image",
            "probe": disc_probe,
            "expect": {
                "video": True, "audio": True, "seek": True,
                "duration_ms": 8000, "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "container-bivx-dual-audio",
            "ext": "bivx",
            "linear": ["ALL-219"],
            "path": sdir / "dual-audio.bivx",
            "note": "Dual-audio MPEG-4/MP3 AVI renamed .bivx",
            "auto_probe": True,
            "expect": {
                "video": True, "audio": True, "seek": True,
                "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "split-001-mkv",
            "ext": "001",
            "linear": ["ALL-231"],
            "path": sdir / "split-video.mkv.001",
            "note": "Split .001 + .002 MKV volume via ffmpeg://concat:",
            "probe": {
                "container": "matroska",
                "duration_ms": 6000,
                "video_codec": "h264",
                "pix_fmt": "yuv420p",
                "width": 640,
                "height": 360,
                "sar": "1:1",
                "audio_codec": "aac",
                "channels": 1,
                "sample_rate": 48000,
            },
            "expect": {
                "video": True, "audio": True, "seek": True,
                "duration_ms": 6000, "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
        # --- Batch 2 ---
        {
            "id": "audio-dtshd-ma",
            "ext": "mka",
            "linear": ["ALL-308"],
            "path": sdir / "pure_lossless_dtshd_ma.mka",
            "note": "Pure Lossless DTS-HD MA (samples.ffmpeg.org trac/ticket4619)",
            "auto_probe": True,
            "expect": {
                "video": False, "audio": True, "seek": True,
                "play_to_end": False, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "audio-dolby-atmos-truehd",
            "ext": "mka",
            "linear": ["ALL-309"],
            "path": b2dir / "dolby_atmos_music_demo.mka",
            "note": "Dolby TrueHD + Dolby Atmos 7.1 (samples.ffmpeg.org trac/ticket7988)",
            "auto_probe": True,
            "expect": {
                "video": False, "audio": True, "seek": True,
                "play_to_end": False, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "audio-dtsx-714",
            "ext": "mka",
            "linear": ["ALL-310"],
            "path": sdir / "dtsx_7.1.4_looped.mka",
            "note": "DTS-HD MA + DTS:X 7.1.4 (from FFmpeg FATE dtsx_7.1.4_24bit.dts)",
            "auto_probe": True,
            "expect": {
                "video": False, "audio": True, "seek": True,
                "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "audio-adp-gamecube",
            "ext": "adp",
            "linear": ["ALL-358"],
            "path": sdir / "shakespr_looped.adp",
            "note": "GameCube ADPCM DTK .adp (from FFmpeg FATE shakespr_partial.adp)",
            "auto_probe": True,
            "expect": {
                "video": False, "audio": True, "seek": True,
                "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
        {
            "id": "audio-afc-gamecube",
            "ext": "afc",
            "linear": ["ALL-359"],
            "path": sdir / "tone.afc",
            "note": "GameCube ADPCM .afc (32kHz stereo, 4s)",
            "auto_probe": True,
            "expect": {
                "video": False, "audio": True, "seek": True,
                "play_to_end": True, "frame": None, "tone_hz": None,
            },
        },
    ]

    samples = []
    for c in cases:
        p: pathlib.Path = c["path"]
        if not p.is_file():
            samples.append({
                "id": c["id"], "ext": c["ext"], "linear": c["linear"],
                "note": c["note"], "status": "error", "error": f"missing {p}",
            })
            continue
        probe = ffprobe_info(p) if c.get("auto_probe") else c["probe"]
        expect = dict(c["expect"])
        if "duration_ms" not in expect:
            expect["duration_ms"] = probe["duration_ms"] or None
        samples.append({
            "id": c["id"],
            "ext": c["ext"],
            "linear": c["linear"],
            "note": c["note"],
            "status": "ok",
            "path": str(p),
            "sha256": sha256_file(p),
            "bytes": p.stat().st_size,
            "probe": probe,
            "expect": expect,
        })

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"samples": samples}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"prepared {len(samples)} Batch 1+2 sample(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
