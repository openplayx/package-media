#!/usr/bin/env python3
"""Prepare the 10 fixable failed ALL-209 items for package-media verification:
  - ALL-227: .dvr-ms
  - ALL-234: .asx (XML playlist resolved natively by MpvBackend)
  - ALL-237: .mk3d (Matroska 3D stereo display ratio)
  - ALL-249: .wv (WavPack)
  - ALL-251: .shn (Shorten)
  - ALL-252: .mac (Monkey's Audio)
  - ALL-267 / ALL-268 / ALL-269: .mpc / .mpp / .mp+ (Musepack SV7 with hr-seek=yes)
  - ALL-273: .aa (Audible AA)
"""
from __future__ import annotations

import argparse
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
    args = ap.parse_args()

    pack = args.pack.resolve()
    stage = args.out.parent / "stage"
    stage.mkdir(parents=True, exist_ok=True)

    baseline_mp4 = pack / "fixtures/common/baseline.mp4"
    asx_file = stage / "test.asx"
    asx_file.write_text(
        f'<ASX version="3.0"><ENTRY><TITLE>OpenPlayX</TITLE><REF HREF="{baseline_mp4.as_uri()}"/></ENTRY></ASX>\n',
        encoding="utf-8",
    )

    mac_file = stage / "luckynight-mac394b1-c2000.mac"
    shutil.copy2(pack / "public/ffmpeg-fate/luckynight-mac394b1-c2000.ape", mac_file)

    mpp_file = stage / "inside-mp7.mpp"
    mp_plus_file = stage / "inside-mp7.mp+"
    shutil.copy2(pack / "public/ffmpeg-fate/inside-mp7.mpc", mpp_file)
    shutil.copy2(pack / "public/ffmpeg-fate/inside-mp7.mpc", mp_plus_file)

    cases = [
        {"id": "fix-all-227-dvr-ms", "linear": ["ALL-227"], "ext": "dvr-ms", "path": pack / "public/ffmpeg-samples/SS2.dvr-ms", "seek": False, "dur_check": False, "note": "SS2.dvr-ms (SAR 8:9 displayH)"},
        {"id": "fix-all-234-asx", "linear": ["ALL-234"], "ext": "asx", "path": asx_file, "probe_path": baseline_mp4, "seek": True, "dur_check": True, "note": "test.asx resolved by MpvBackend"},
        {"id": "fix-all-237-mk3d", "linear": ["ALL-237"], "ext": "mk3d", "path": pack / "fixtures/video/stereo.mk3d", "seek": True, "dur_check": True, "note": "stereo.mk3d (SBS 3D)"},
        {"id": "fix-all-249-wv", "linear": ["ALL-249"], "ext": "wv", "path": pack / "public/ffmpeg-fate/2.0_32-bit_float.wv", "seek": True, "dur_check": True, "note": "2.0_32-bit_float.wv (WavPack)"},
        {"id": "fix-all-251-shn", "linear": ["ALL-251"], "ext": "shn", "path": pack / "public/ffmpeg-fate/luckynight-partial.shn", "seek": False, "dur_check": False, "note": "luckynight-partial.shn (Shorten, non-seekable)"},
        {"id": "fix-all-252-mac", "linear": ["ALL-252"], "ext": "mac", "path": mac_file, "seek": False, "dur_check": False, "note": "luckynight-mac394b1-c2000.mac (truncated FATE APE)"},
        {"id": "fix-all-267-mpc", "linear": ["ALL-267"], "ext": "mpc", "path": pack / "public/ffmpeg-fate/inside-mp7.mpc", "seek": True, "dur_check": True, "note": "inside-mp7.mpc (Musepack SV7 hr-seek)"},
        {"id": "fix-all-268-mpp", "linear": ["ALL-268"], "ext": "mpp", "path": mpp_file, "seek": True, "dur_check": True, "note": "inside-mp7.mpp (Musepack SV7 hr-seek)"},
        {"id": "fix-all-269-mp+", "linear": ["ALL-269"], "ext": "mp+", "path": mp_plus_file, "seek": True, "dur_check": True, "note": "inside-mp7.mp+ (Musepack SV7 hr-seek)"},
        {"id": "fix-all-273-aa", "linear": ["ALL-273"], "ext": "aa", "path": pack / "public/ffmpeg-fate/bush.aa", "seek": False, "dur_check": False, "note": "bush.aa (truncated FATE AA)"},
    ]

    samples = []
    for c in cases:
        p = c["path"]
        info = probe(c.get("probe_path", p))
        dur_ms = info["duration_ms"] or 0
        expect = {
            "video": bool(info["video_codec"]),
            "audio": bool(info["audio_codec"]),
            "seek": c["seek"],
            "duration_ms": dur_ms if (c["dur_check"] and dur_ms > 0) else None,
            "play_to_end": c["seek"] and (0 < dur_ms <= 20000),
            "frame": None,
            "tone_hz": None,
        }
        samples.append({
            "id": c["id"],
            "ext": c["ext"],
            "linear": c["linear"],
            "note": c["note"],
            "status": "ok",
            "path": str(p),
            "sha256": sha256_file(p),
            "bytes": p.stat().st_size,
            "probe": info,
            "expect": expect,
        })

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps({"samples": samples}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"prepared {len(samples)} failed-fix sample(s) -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
