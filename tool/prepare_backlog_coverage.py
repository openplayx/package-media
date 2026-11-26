#!/usr/bin/env python3
"""Prepare the 15 actionable ALL-209 Backlog test cases for package-media:
  - ALL-296: VC-1 video codec
  - ALL-311..ALL-321: 11 subtitle formats (external SRT/ASS/SSA/VTT/VobSub/PGS/MKS/SAMI + embedded MovText/EIA-608/EIA-708)
  - ALL-246 / ALL-362 / ALL-369: .strm, .cue, .pls reference/playlist formats

Usage:
  prepare_backlog_coverage.py --out FILE [--pack DIR] [--only GLOB[,GLOB...]]
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

ROOT = pathlib.Path(__file__).resolve().parents[1]


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def probe(path: pathlib.Path) -> dict:
    p = subprocess.run(
        ["ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", str(path)],
        capture_output=True, text=True, check=True,
    )
    data = json.loads(p.stdout)
    streams = data.get("streams") or []
    v = next((s for s in streams if s.get("codec_type") == "video" and not (s.get("disposition") or {}).get("attached_pic")), None)
    a = next((s for s in streams if s.get("codec_type") == "audio"), None)
    dur = float((data.get("format") or {}).get("duration") or (v or a or {}).get("duration") or 0)
    return {
        "container": (data.get("format") or {}).get("format_name"),
        "duration_ms": round(dur * 1000),
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
    ap.add_argument("--pack", type=pathlib.Path, default=ROOT.parent / "openplayx-test/formats")
    ap.add_argument("--out", type=pathlib.Path, required=True)
    ap.add_argument("--only", default="")
    args = ap.parse_args()

    pack = args.pack.resolve()
    baseline_mp4 = pack / "fixtures/common/baseline.mp4"
    baseline_probe = probe(baseline_mp4)
    stage = args.out.parent / "stage"
    stage.mkdir(parents=True, exist_ok=True)

    # Rewrite .strm and .pls to local file URIs so tests run fully offline.
    strm_file = stage / "test.strm"
    strm_file.write_text(baseline_mp4.as_uri() + "\n", encoding="utf-8")

    pls_target = pack / "fixtures/audio/mp3.mp3"
    pls_file = stage / "test.pls"
    pls_file.write_text(
        f"[playlist]\nNumberOfEntries=1\nFile1={pls_target.as_uri()}\nTitle1=OpenPlayX\nLength1=3\nVersion=2\n",
        encoding="utf-8",
    )

    cue_file = pack / "fixtures/reference/tone.cue"
    cue_target = pack / "fixtures/reference/tone.wav"

    # Define all 15 Backlog items
    cases: list[dict] = [
        {
            "id": "backlog-all-296-vc1",
            "linear": ["ALL-296"],
            "ext": "vc1",
            "path": pack / "public/ffmpeg-fate/SA00040.vc1",
            "note": "VC-1 elementary stream",
            "raw": True,
        },
        # 8 external subtitle formats paired with baseline.mp4
        {"id": "backlog-all-311-srt", "linear": ["ALL-311"], "ext": "srt", "path": baseline_mp4, "ext_sub": pack / "fixtures/subtitle/baseline.srt", "note": "External SRT subtitle"},
        {"id": "backlog-all-312-ass", "linear": ["ALL-312"], "ext": "ass", "path": baseline_mp4, "ext_sub": pack / "fixtures/subtitle/baseline.ass", "note": "External ASS subtitle"},
        {"id": "backlog-all-313-ssa", "linear": ["ALL-313"], "ext": "ssa", "path": baseline_mp4, "ext_sub": pack / "fixtures/subtitle/baseline.ssa", "note": "External SSA subtitle"},
        {"id": "backlog-all-314-vtt", "linear": ["ALL-314"], "ext": "vtt", "path": baseline_mp4, "ext_sub": pack / "fixtures/subtitle/baseline.vtt", "note": "External WebVTT subtitle"},
        {"id": "backlog-all-315-vobsub", "linear": ["ALL-315"], "ext": "idx", "path": baseline_mp4, "ext_sub": pack / "public/ffmpeg-fate/vobsub.idx", "note": "External VobSub (SUB+IDX) subtitle"},
        {"id": "backlog-all-316-pgs", "linear": ["ALL-316"], "ext": "sup", "path": baseline_mp4, "ext_sub": pack / "public/ffmpeg-fate/pgs_sub.sup", "note": "External PGS (SUP) subtitle"},
        {"id": "backlog-all-317-mks", "linear": ["ALL-317"], "ext": "mks", "path": baseline_mp4, "ext_sub": pack / "fixtures/subtitle/baseline.mks", "note": "External Matroska MKS subtitle"},
        {"id": "backlog-all-318-sami", "linear": ["ALL-318"], "ext": "sami", "path": baseline_mp4, "ext_sub": pack / "fixtures/subtitle/baseline.sami", "note": "External SAMI subtitle"},
        # 3 embedded subtitle / closed-caption formats
        {"id": "backlog-all-319-mov_text", "linear": ["ALL-319"], "ext": "mp4", "path": pack / "fixtures/subtitle/timed-text.mp4", "min_subs": 1, "note": "MP4 Timed Text (mov_text)"},
        {"id": "backlog-all-320-eia608", "linear": ["ALL-320"], "ext": "m2v", "path": pack / "public/ffmpeg-fate/Closedcaption_rollup.m2v", "min_subs": 1, "raw": True, "note": "EIA-608 closed captions in MPEG-2"},
        {"id": "backlog-all-321-eia708", "linear": ["ALL-321"], "ext": "mpg", "path": pack / "public/pixeltools/cea708_dtv.mpg", "min_subs": 1, "raw": True, "note": "EIA-708 DTV closed captions in MPEG-2"},
        # 3 playlist / reference formats
        {"id": "backlog-all-246-strm", "linear": ["ALL-246"], "ext": "strm", "path": strm_file, "probe_path": baseline_mp4, "note": ".strm pointer to baseline.mp4"},
        {"id": "backlog-all-362-cue", "linear": ["ALL-362"], "ext": "cue", "path": cue_file, "probe_path": cue_target, "note": ".cue sheet pointing to tone.wav"},
        {"id": "backlog-all-369-pls", "linear": ["ALL-369"], "ext": "pls", "path": pls_file, "probe_path": pls_target, "note": ".pls playlist pointing to mp3.mp3"},
    ]

    patterns = [p.strip() for p in args.only.split(",") if p.strip()]
    samples = []
    for c in cases:
        if patterns and not any(fnmatch.fnmatch(c["id"], pat) for pat in patterns):
            continue
        media_path: pathlib.Path = c["path"]
        ext_sub: pathlib.Path | None = c.get("ext_sub")
        entry = {"id": c["id"], "ext": c["ext"], "linear": c["linear"], "note": c["note"]}
        if not media_path.is_file():
            entry.update(status="error", error=f"missing media file: {media_path}")
            samples.append(entry)
            continue
        if ext_sub and not ext_sub.is_file():
            entry.update(status="error", error=f"missing subtitle file: {ext_sub}")
            samples.append(entry)
            continue

        info = baseline_probe if media_path == baseline_mp4 else probe(c.get("probe_path", media_path))
        raw = bool(c.get("raw"))
        dur_ms = info["duration_ms"] or 0
        expect = {
            "video": bool(info["video_codec"]),
            "audio": bool(info["audio_codec"]),
            "seek": (not raw) and dur_ms >= 2500,
            "duration_ms": None if (raw or dur_ms <= 0) else dur_ms,
            "play_to_end": (not raw) and (0 < dur_ms <= 20000),
            "frame": None,
            "tone_hz": None,
        }
        if ext_sub:
            expect["external_subtitle"] = str(ext_sub)
        if c.get("min_subs"):
            expect["min_subtitle_tracks"] = c["min_subs"]

        entry.update(
            status="ok",
            path=str(media_path),
            sha256=sha256_file(ext_sub or media_path),
            bytes=(ext_sub or media_path).stat().st_size,
            probe=info,
            expect=expect,
        )
        samples.append(entry)

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"samples": samples}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"prepared {len(samples)} backlog coverage sample(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
