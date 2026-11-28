#!/usr/bin/env python3
"""Generate all video, audio, external subtitle, and embedded-subtitle assets
defined in package-media/formats/subtitle-sync-tests.json.

Every video uses a deterministic ground-truth timecode signal:
  - Video: FFmpeg testsrc2 (built-in live frame counter & timecode) + high-contrast
    drawbox sync marker flashing for 200ms at exact cue start timestamps.
  - Audio: Exact 1000Hz 150ms sine beeps at cue start timestamps (or macOS `say`
    TTS spoken cues for ASR cases).
  - Subtitles: All 27 external subtitle formats/edge-cases + 5 negative controls
    + 438 independent embedded-subtitle muxed videos (Option 1).

Usage:
  python3 package-media/tool/generate_subtitle_sync_assets.py
  python3 package-media/tool/generate_subtitle_sync_assets.py --only 'v-mp4-*'
  python3 package-media/tool/generate_subtitle_sync_assets.py --out materials/subtitle-sync --workers 6
"""
from __future__ import annotations

import argparse
import concurrent.futures
import fnmatch
import json
import os
import pathlib
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import wave
import math

ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "formats" / "subtitle-sync-tests.json"
DEFAULT_OUT = ROOT.parent / "materials" / "subtitle-sync"


def run_cmd(cmd: list[str], cwd: pathlib.Path | None = None, timeout: int = 300) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def cues_for_duration(duration_sec: int, pattern: str = "standard") -> list[tuple[int, int, str]]:
    """Return list of (start_ms, end_ms, text) cues."""
    if pattern == "long_cue_2s_to_12s":
        return [(2000, 12000, "LONG CUE 02s-12s SEEK MID TEST")]
    if pattern == "overlapping_cues":
        return [
            (1000, 4000, "SPEAKER A: CUE 01 (01s-04s)"),
            (2500, 5500, "SPEAKER B: CUE 02 OVERLAP (02.5s-05.5s)"),
            (7000, 10000, "SPEAKER A: CUE 03 (07s-10s)"),
            (8000, 11500, "SPEAKER B: CUE 04 OVERLAP (08s-11.5s)"),
        ]
    if pattern == "zero_gap_back_to_back":
        return [(i * 2000, (i + 1) * 2000, f"B2B CUE {i:02d}") for i in range(1, 7)]
    if pattern == "ultra_short_150ms":
        return [((2 * i - 1) * 1000, (2 * i - 1) * 1000 + 150, f"FLASH {i:02d}") for i in range(1, 8)]
    if pattern == "out_of_order_and_dup_index":
        return [
            (3000, 4000, "CUE 02 (OUT OF ORDER)"),
            (1000, 2000, "CUE 01 (OUT OF ORDER)"),
            (5000, 6000, "CUE 03"),
            (7000, 8000, "CUE 04"),
            (9000, 10000, "CUE 05"),
            (11000, 12000, "CUE 06"),
            (13000, 14000, "CUE 07"),
        ]
    if pattern == "heavy_fx_karaoke_move_cjk_rtl_emoji":
        return [
            (1000, 2500, r"{\k50}CUE {\k50}01 {\k50}中文字幕 مرحبا 🎬"),
            (3000, 4500, r"{\move(80,320,560,320)}CUE 02 MOVE TEST"),
            (5000, 6500, r"{\t(0,1000,\fscx150\fscy150)}CUE 03 SCALE FX"),
            (7000, 8500, r"{\k40}CUE {\k40}04 {\k40}日本語 테스트"),
            (9000, 10500, r"{\move(560,320,80,320)}CUE 05 REVERSE MOVE"),
            (11000, 12500, r"{\fad(300,300)}CUE 06 FADE FX"),
            (13000, 14500, r"{\k50}CUE {\k50}07 {\k50}FINAL 🏁"),
        ]
    if duration_sec >= 1800:
        # Sparse cues across 30 minutes
        mins = [0, 5, 10, 15, 20, 25, 29]
        return [(m * 60000 + 5000, m * 60000 + 8000, f"CUE {i+1:02d} AT {m:02d}M05S") for i, m in enumerate(mins)]
    if duration_sec >= 60:
        return [((2 * i - 1) * 1000, (2 * i) * 1000, f"CUE {i:02d}") for i in range(1, 30)]
    return [((2 * i - 1) * 1000, (2 * i) * 1000, f"CUE {i:02d}") for i in range(1, 8)]


def fmt_srt_time(ms: int) -> str:
    ms = max(0, ms)
    h = ms // 3600000
    m = (ms // 60000) % 60
    s = (ms // 1000) % 60
    rem = ms % 1000
    return f"{h:02d}:{m:02d}:{s:02d},{rem:03d}"


def fmt_vtt_time(ms: int) -> str:
    return fmt_srt_time(ms).replace(",", ".")


def fmt_ass_time(ms: int) -> str:
    ms = max(0, ms)
    h = ms // 3600000
    m = (ms // 60000) % 60
    s = (ms // 1000) % 60
    cs = (ms % 1000) // 10
    return f"{h:d}:{m:02d}:{s:02d}.{cs:02d}"


def write_pgs_sup(path: pathlib.Path, cues: list[tuple[int, int, str]], width: int = 640, height: int = 360) -> None:
    """Write a valid Blu-ray PGS (.sup) file with a bright 160x32 bar per cue."""
    def seg(pts_ms: int, seg_type: int, payload: bytes) -> bytes:
        pts = int(round(max(0, pts_ms) * 90))
        return b"PG" + struct.pack(">IIBH", pts, 0, seg_type, len(payload)) + payload

    bw, bh = 160, 32
    line = bytes([0x00, 0xC0 | (bw >> 8), bw & 0xFF, 0x01, 0x00, 0x00])
    rle = line * bh
    bx, by = (width - bw) // 2, height - bh - 20

    out = bytearray()
    comp_num = 0
    for start_ms, end_ms, _ in cues:
        pcs = struct.pack(">HHBHBBBB", width, height, 0x10, comp_num, 0x80, 0x00, 0x00, 1)
        pcs += struct.pack(">HBBHH", 0, 0, 0x00, bx, by)
        wds = struct.pack(">BBHHHH", 1, 0, bx, by, bw, bh)
        pds = struct.pack(">BB", 0, 0)
        pds += struct.pack(">BBBBB", 0, 16, 128, 128, 0)    # transparent
        pds += struct.pack(">BBBBB", 1, 235, 128, 128, 255)  # opaque white
        pds += struct.pack(">BBBBB", 2, 16, 128, 128, 255)   # opaque black
        pds += struct.pack(">BBBBB", 3, 210, 16, 146, 255)   # opaque yellow
        ods_data_len = 4 + len(rle)
        ods = struct.pack(">HBB", 0, 0, 0xC0) + ods_data_len.to_bytes(3, "big") + struct.pack(">HH", bw, bh) + rle
        out += seg(start_ms, 0x16, pcs)
        out += seg(start_ms, 0x17, wds)
        out += seg(start_ms, 0x14, pds)
        out += seg(start_ms, 0x15, ods)
        out += seg(start_ms, 0x80, b"")
        comp_num += 1

        pcs_clear = struct.pack(">HHBHBBBB", width, height, 0x10, comp_num, 0x00, 0x00, 0x00, 0)
        out += seg(end_ms, 0x16, pcs_clear)
        out += seg(end_ms, 0x80, b"")
        comp_num += 1

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(out)


def write_vobsub_pair(idx_path: pathlib.Path, cues: list[tuple[int, int, str]]) -> None:
    """Create a valid VobSub (.idx + .sub) pair by encoding PGS -> dvdsub in MPEG-PS (.sub)
    and writing the matching .idx timestamp/filepos index."""
    sub_path = idx_path.with_suffix(".sub")
    with tempfile.TemporaryDirectory() as td:
        sup = pathlib.Path(td) / "tmp.sup"
        write_pgs_sup(sup, cues)
        # Mux dvdsub into MPEG-PS packets; each SPU sits in a private_stream_1 pack
        cmd = [
            "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
            "-i", str(sup), "-c:s", "dvdsub", "-f", "vob", str(sub_path),
        ]
        r = run_cmd(cmd)
        if r.returncode != 0:
            raise RuntimeError(f"vobsub sub generation failed: {r.stderr.strip()}")

    # Locate MPEG-PS pack headers (00 00 01 BA) in .sub for filepos entries
    data = sub_path.read_bytes()
    pack_positions = []
    pos = 0
    while True:
        idx = data.find(b"\x00\x00\x01\xba", pos)
        if idx == -1:
            break
        pack_positions.append(idx)
        pos = idx + 4
    if not pack_positions:
        pack_positions = [0]

    lines = [
        "# VobSub index file, v7 (do not modify this line!)",
        "size: 640x360",
        "org: 0, 0",
        "scale: 100%, 100%",
        "alpha: 100%",
        "smooth: OFF",
        "fadein/out: 0, 0",
        "align: OFF at LEFT TOP",
        "time offset: 0",
        "forced subs: OFF",
        "palette: 000000, ffffff, 000000, ffff00, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000, 000000",
        "custom colors: OFF, tridx: 1000, colors: 000000, ffffff, 000000, ffff00",
        "langidx: 0",
        "id: en, index: 0",
    ]
    for i, (start_ms, _, _) in enumerate(cues):
        fpos = pack_positions[min(i, len(pack_positions) - 1)]
        h = start_ms // 3600000
        m = (start_ms // 60000) % 60
        s = (start_ms // 1000) % 60
        ms = start_ms % 1000
        lines.append(f"timestamp: {h:02d}:{m:02d}:{s:02d}:{ms:03d}, filepos: {fpos:09x}")
    idx_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_subtitle_file(sub_spec: dict, out_dir: pathlib.Path, duration_sec: int = 15, fps: float = 25.0) -> pathlib.Path:
    """Generate an external or negative-control subtitle file."""
    sid = sub_spec["id"]
    fmt = sub_spec["format"]
    ext = sub_spec["ext"]
    pattern = sub_spec.get("content_pattern", "standard")
    cues = cues_for_duration(duration_sec, pattern)

    # Apply negative-control distortions if applicable
    if sid == "neg-srt-offset-plus500ms":
        cues = [(s + 500, e + 500, t) for s, e, t in cues]
    elif sid == "neg-srt-offset-minus500ms":
        cues = [(max(0, s - 500), max(100, e - 500), t) for s, e, t in cues]
    elif sid == "neg-srt-offset-plus2000ms":
        cues = [(s + 2000, e + 2000, t) for s, e, t in cues]
    elif sid == "neg-srt-fps-drift-23976-vs-25":
        scale = 23.976 / 25.0
        cues = [(int(round(s * scale)), int(round(e * scale)), t) for s, e, t in cues]
    elif sid == "neg-srt-mid-cut-jump-1500ms":
        cues = [(s + (1500 if s >= 7000 else 0), e + (1500 if s >= 7000 else 0), t) for s, e, t in cues]

    suffix = f"_{duration_sec}s" if duration_sec != 15 else ""
    out_path = out_dir / f"{sid}{suffix}.{ext}"
    out_path.parent.mkdir(parents=True, exist_ok=True)

    if fmt in ("srt", "srt_bom_crlf", "srt_gb18030", "srt_utf16le"):
        sep = "\r\n" if fmt == "srt_bom_crlf" else "\n"
        blocks = []
        for idx, (s, e, text) in enumerate(cues, 1):
            num = 1 if (pattern == "out_of_order_and_dup_index" and idx == 2) else idx
            t = f"{text} 中文测试" if fmt == "srt_gb18030" else text
            blocks.append(f"{num}{sep}{fmt_srt_time(s)} --> {fmt_srt_time(e)}{sep}{t}{sep}")
        content = sep.join(blocks)
        enc = sub_spec.get("encoding", "utf-8")
        out_path.write_bytes(content.encode(enc))
    elif fmt == "vtt":
        lines = ["WEBVTT", ""]
        for s, e, text in cues:
            lines.append(f"{fmt_vtt_time(s)} --> {fmt_vtt_time(e)}")
            lines.append(text)
            lines.append("")
        out_path.write_text("\n".join(lines), encoding="utf-8")
    elif fmt == "ass":
        header = (
            "[Script Info]\nScriptType: v4.00+\nPlayResX: 640\nPlayResY: 360\n\n"
            "[V4+ Styles]\n"
            "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, "
            "Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, "
            "Alignment, MarginL, MarginR, MarginV, Encoding\n"
            "Style: Default,Arial,26,&H00FFFFFF,&H0000FFFF,&H00000000,&H80000000,-1,0,0,0,100,100,0,0,1,2,0,2,20,20,24,1\n"
            "Style: Box,Arial,20,&H0000FF00,&H0000FF00,&H0000FF00,&H0000FF00,0,0,0,0,100,100,0,0,3,0,0,3,10,10,10,1\n\n"
            "[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
        )
        events = []
        for idx, (s, e, text) in enumerate(cues):
            layer = idx % 2 if pattern == "overlapping_cues" else 0
            events.append(f"Dialogue: {layer},{fmt_ass_time(s)},{fmt_ass_time(e)},Default,,0,0,0,,{text}")
            # Fixed green sync square at bottom-right for zero-OCR pixel detection
            events.append(f"Dialogue: 1,{fmt_ass_time(s)},{fmt_ass_time(min(e, s + 200))},Box,,0,0,0,,SYNC")
        out_path.write_text(header + "\n".join(events) + "\n", encoding="utf-8")
    elif fmt == "ssa":
        header = (
            "[Script Info]\nScriptType: v4.00\nPlayResX: 640\nPlayResY: 360\n\n"
            "[V4 Styles]\n"
            "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, TertiaryColour, BackColour, "
            "Bold, Italic, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, AlphaLevel, Encoding\n"
            "Style: Default,Arial,26,16777215,65535,0,0,-1,0,1,2,0,2,20,20,24,0,1\n\n"
            "[Events]\nFormat: Marked, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
        )
        events = [f"Dialogue: Marked=0,{fmt_ass_time(s)},{fmt_ass_time(e)},Default,,0,0,0,,{text}" for s, e, text in cues]
        out_path.write_text(header + "\n".join(events) + "\n", encoding="utf-8")
    elif fmt == "sami":
        body = ["<SAMI><HEAD><STYLE TYPE='text/css'><!-- P { font-family: Arial; color: white; } --></STYLE></HEAD><BODY>"]
        for s, e, text in cues:
            body.append(f"<SYNC Start={s}><P>{text}</P></SYNC>")
            body.append(f"<SYNC Start={e}><P>&nbsp;</P></SYNC>")
        body.append("</BODY></SAMI>")
        out_path.write_text("\n".join(body) + "\n", encoding="utf-8")
    elif fmt == "ttml":
        body = [
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">',
            "  <body><div>",
        ]
        for s, e, text in cues:
            body.append(f'    <p begin="{fmt_vtt_time(s)}" end="{fmt_vtt_time(e)}">{text}</p>')
        body.append("  </div></body>\n</tt>")
        out_path.write_text("\n".join(body) + "\n", encoding="utf-8")
    elif fmt == "sbv":
        blocks = [f"{fmt_vtt_time(s)[1:]},{fmt_vtt_time(e)[1:]}\n{text}\n" for s, e, text in cues]
        out_path.write_text("\n".join(blocks), encoding="utf-8")
    elif fmt == "subviewer":
        header = "[INFORMATION]\n[TITLE]Subtitle Sync\n[END INFORMATION]\n[SUBTITLE]\n"
        def sv(ms: int) -> str:
            h, m, s, cs = ms // 3600000, (ms // 60000) % 60, (ms // 1000) % 60, (ms % 1000) // 10
            return f"{h:02d}:{m:02d}:{s:02d}.{cs:02d}"
        blocks = [f"{sv(s)},{sv(e)}\n{text}\n" for s, e, text in cues]
        out_path.write_text(header + "\n".join(blocks), encoding="utf-8")
    elif fmt == "mpl2":
        lines = [f"[{s // 100}][{e // 100}]{text}" for s, e, text in cues]
        out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    elif fmt == "lrc":
        lines = []
        for s, e, text in cues:
            m1, s1, cs1 = s // 60000, (s // 1000) % 60, (s % 1000) // 10
            m2, s2, cs2 = e // 60000, (e // 1000) % 60, (e % 1000) // 10
            lines.append(f"[{m1:02d}:{s1:02d}.{cs1:02d}]{text}")
            lines.append(f"[{m2:02d}:{s2:02d}.{cs2:02d}]")
        out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    elif fmt == "scc":
        # Minimal valid Scenarist Closed Caption (.scc) header + cue markers
        lines = ["Scenarist_SCC V1.0", ""]
        def smpte(ms: int) -> str:
            h = ms // 3600000
            m = (ms // 60000) % 60
            s = (ms // 1000) % 60
            f = int(round((ms % 1000) * 29.97 / 1000.0)) % 30
            return f"{h:02d}:{m:02d}:{s:02d}:{f:02d}"
        for idx, (s, e, _) in enumerate(cues, 1):
            # Pop-on caption with "CUE 0X"
            c_hi = f"30{ord('0') + (idx % 10):02x}"
            lines.append(f"{smpte(s)}\t9420 9420 94ae 94ae 9470 9470 43d5 4520 {c_hi} 942f 942f")
            lines.append("")
            lines.append(f"{smpte(e)}\t942c 942c")
            lines.append("")
        out_path.write_text("\n".join(lines), encoding="utf-8")
    elif fmt == "microdvd":
        lines = [f"{{1}}{{1}}{fps:.3f}"]
        for s, e, text in cues:
            sf = int(round(s * fps / 1000.0))
            ef = int(round(e * fps / 1000.0))
            lines.append(f"{{{sf}}}{{{ef}}}{text}")
        out_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    elif fmt == "mks":
        with tempfile.TemporaryDirectory() as td:
            tmp_srt = pathlib.Path(td) / "in.srt"
            tmp_srt.write_text(
                "\n".join(f"{i}\n{fmt_srt_time(s)} --> {fmt_srt_time(e)}\n{t}\n" for i, (s, e, t) in enumerate(cues, 1)),
                encoding="utf-8",
            )
            r = run_cmd(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(tmp_srt), "-c:s", "subrip", "-f", "matroska", str(out_path)])
            if r.returncode != 0:
                raise RuntimeError(f"mks mux failed: {r.stderr.strip()}")
    elif fmt == "pgs":
        write_pgs_sup(out_path, cues)
    elif fmt == "vobsub":
        write_vobsub_pair(out_path, cues)
    else:
        raise ValueError(f"Unsupported subtitle format: {fmt}")

    return out_path


def generate_beep_wav(wav_path: pathlib.Path, duration_sec: int, cues: list[tuple[int, int, str]], sample_rate: int = 48000, add_noise: bool = False) -> None:
    """Synthesize a clean PCM WAV with exact 1000Hz 150ms sine bursts at each cue start."""
    n_samples = duration_sec * sample_rate
    buf = bytearray(n_samples * 2)  # 16-bit mono
    beep_len = int(0.150 * sample_rate)
    for start_ms, _, _ in cues:
        s0 = int(start_ms * sample_rate / 1000)
        for j in range(beep_len):
            idx = s0 + j
            if idx >= n_samples:
                break
            # Smooth 5ms fade in/out to avoid click
            env = 1.0
            if j < 240:
                env = j / 240.0
            elif j > beep_len - 240:
                env = (beep_len - j) / 240.0
            val = int(round(20000 * env * math.sin(2.0 * math.pi * 1000.0 * j / sample_rate)))
            struct.pack_into("<h", buf, idx * 2, val)
    with wave.open(str(wav_path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(buf)


def generate_tts_wav(wav_path: pathlib.Path, duration_sec: int, cues: list[tuple[int, int, str]], vid: str) -> None:
    """Generate a PCM WAV with macOS `say` spoken phrases placed at exact cue timestamps."""
    sample_rate = 48000
    n_samples = duration_sec * sample_rate
    mix = [0] * n_samples

    # Silence intro case: cues start at 30s
    if "silence-intro" in vid:
        cues = [(30000 + i * 4000, 32000 + i * 4000, f"Cue {i + 1}, after silence") for i in range(6)]
    elif "multilingual" in vid:
        phrases = [
            (1000, "Cue one, hello world", "Samantha"),
            (4000, "第二句，中文字幕同步测试", "Tingting"),
            (7500, "Cue three, mixed language", "Samantha"),
            (10500, "第四句，验证对齐精度", "Tingting"),
        ]
        cues = [(t, t + 2000, f"{p}|{v}") for t, p, v in phrases]

    with tempfile.TemporaryDirectory() as td:
        td_path = pathlib.Path(td)
        for idx, (start_ms, _, text) in enumerate(cues):
            voice = "Samantha"
            spoken = text
            if "|" in text:
                spoken, voice = text.split("|", 1)
            aiff = td_path / f"say_{idx}.aiff"
            pcm = td_path / f"say_{idx}.wav"
            r = run_cmd(["say", "-v", voice, "-o", str(aiff), spoken])
            if r.returncode != 0:
                # Fallback to default system voice if Samantha/Tingting unavailable
                r = run_cmd(["say", "-o", str(aiff), spoken])
            if r.returncode != 0:
                continue
            r2 = run_cmd(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(aiff), "-ac", "1", "-ar", str(sample_rate), "-c:a", "pcm_s16le", str(pcm)])
            if r2.returncode != 0:
                continue
            with wave.open(str(pcm), "rb") as wf:
                raw = wf.readframes(wf.getnframes())
            samples = struct.unpack(f"<{len(raw)//2}h", raw)
            s0 = int(start_ms * sample_rate / 1000)
            for j, val in enumerate(samples):
                if s0 + j < n_samples:
                    mix[s0 + j] = max(-32767, min(32767, mix[s0 + j] + val))

    # Optional pink-ish BGM noise for noisy ASR case
    if "noisy-bgm" in vid:
        for i in range(n_samples):
            bgm = int(3500 * math.sin(2.0 * math.pi * 220.0 * i / sample_rate) + 2500 * math.sin(2.0 * math.pi * 330.0 * i / sample_rate))
            mix[i] = max(-32767, min(32767, mix[i] + bgm))

    with wave.open(str(wav_path), "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f"<{n_samples}h", *mix))


def parse_fps_expr(fps_str: str) -> str:
    if fps_str == "23.976":
        return "24000/1001"
    if fps_str == "29.97":
        return "30000/1001"
    if fps_str == "59.94":
        return "60000/1001"
    if fps_str == "25i":
        return "25"
    if fps_str.startswith("vfr"):
        return "60"
    return fps_str


def build_flash_vf(size: str, cues: list[tuple[int, int, str]], extra_filters: list[str] | None = None) -> str:
    """Build FFmpeg video filter: top-right white flash square at exact cue starts."""
    w, h = [int(x) for x in size.split("x")]
    box = max(24, min(64, h // 6))
    bx = w - box - 12
    by = 12
    # Limit drawbox enable expression size for 60s/1800s videos
    terms = [f"between(t,{s/1000:.3f},{(s+200)/1000:.3f})" for s, _, _ in cues[:30]]
    enable = "+".join(terms) if terms else "0"
    filters = [f"drawbox=x={bx}:y={by}:w={box}:h={box}:color=white@1.0:t=fill:enable='{enable}'"]
    if extra_filters:
        filters.extend(extra_filters)
    return ",".join(filters)


def generate_video_asset(v: dict, out_dir: pathlib.Path, skip_existing: bool = True) -> dict:
    """Generate a single base video/stream asset."""
    vid = v["id"]
    ext = v["ext"]
    dur = v["duration_sec"]
    size = v["size"]
    fps_expr = parse_fps_expr(v["fps"])
    cues = cues_for_duration(dur)

    # Determine target path
    if ext in ("m3u8", "mpd"):
        asset_dir = out_dir / "streams" / vid
        asset_dir.mkdir(parents=True, exist_ok=True)
        out_path = asset_dir / f"index.{ext}"
    elif ext == "bluray":
        asset_dir = out_dir / "discs" / vid / "BDMV" / "STREAM"
        asset_dir.mkdir(parents=True, exist_ok=True)
        out_path = asset_dir / "00000.m2ts"
    elif ext == "001":
        asset_dir = out_dir / "split" / vid
        asset_dir.mkdir(parents=True, exist_ok=True)
        out_path = asset_dir / f"{vid}.mkv.001"
    else:
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / f"{vid}.{ext}"

    if skip_existing and out_path.is_file() and out_path.stat().st_size > 0:
        return {"id": vid, "status": "ok", "path": str(out_path), "bytes": out_path.stat().st_size, "cached": True}

    with tempfile.TemporaryDirectory() as td:
        td_path = pathlib.Path(td)
        wav = td_path / "audio.wav"
        has_audio = v["audio_codec"] is not None
        if has_audio:
            if v["include_tts"]:
                generate_tts_wav(wav, dur, cues, vid)
            else:
                generate_beep_wav(wav, dur, cues)

        # ---- Special complex cases ----
        if "vfr" in v["timestamp_features"]:
            # Build genuine VFR by concatenating 15fps, 30fps, 60fps segments into MKV/MP4/MOV/WebM/FLV
            seg_durs = [dur // 3, dur // 3, dur - 2 * (dur // 3)]
            seg_rates = [15, 30, 60]
            seg_files = []
            offset_t = 0
            for idx, (sd, sr) in enumerate(zip(seg_durs, seg_rates)):
                seg_cues = [(s - offset_t * 1000, e - offset_t * 1000, t) for s, e, t in cues if offset_t * 1000 <= s < (offset_t + sd) * 1000]
                vf = build_flash_vf(size, seg_cues)
                sf = td_path / f"vfr_seg_{idx}.mkv"
                vc_args = ["-c:v", "libvpx-vp9", "-b:v", "800k", "-deadline", "realtime"] if v["video_codec"] == "vp9" else ["-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p"]
                cmd = [
                    "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                    "-f", "lavfi", "-i", f"testsrc2=size={size}:rate={sr}:duration={sd}",
                    "-vf", vf, *vc_args, "-an", str(sf),
                ]
                r = run_cmd(cmd)
                if r.returncode != 0:
                    return {"id": vid, "status": "error", "error": r.stderr.strip()}
                seg_files.append(sf)
                offset_t += sd
            concat_txt = td_path / "concat.txt"
            concat_txt.write_text("\n".join(f"file '{sf}'" for sf in seg_files) + "\n", encoding="utf-8")
            ac_args = ["-c:a", "libopus"] if v["audio_codec"] == "opus" else (["-c:a", "aac", "-ar", "44100"] if ext == "flv" else ["-c:a", "aac"])
            cmd = [
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-f", "concat", "-safe", "0", "-i", str(concat_txt),
                "-i", str(wav), "-map", "0:v", "-map", "1:a",
                "-c:v", "copy", *ac_args, "-fps_mode", "passthrough", "-shortest", str(out_path),
            ]
            r = run_cmd(cmd)
            if r.returncode != 0:
                return {"id": vid, "status": "error", "error": r.stderr.strip()}
            return {"id": vid, "status": "ok", "path": str(out_path), "bytes": out_path.stat().st_size}

        if "pts-discontinuity" in vid:
            # Concatenate two segments where the second has a +30s PTS jump
            p1, p2 = td_path / "p1.ts", td_path / "p2.ts"
            for idx, (p, off, s0, sd) in enumerate([(p1, 0, 0, 7), (p2, 30, 7, 8)]):
                sc = [(s - s0 * 1000, e - s0 * 1000, t) for s, e, t in cues if s0 * 1000 <= s < (s0 + sd) * 1000]
                vf = build_flash_vf(size, sc)
                cmd = [
                    "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                    "-f", "lavfi", "-i", f"testsrc2=size={size}:rate=25:duration={sd}",
                    "-ss", str(s0), "-t", str(sd), "-i", str(wav),
                    "-vf", vf, "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
                    "-c:a", "aac", "-output_ts_offset", str(off), "-f", "mpegts", str(p),
                ]
                r = run_cmd(cmd)
                if r.returncode != 0:
                    return {"id": vid, "status": "error", "error": r.stderr.strip()}
            if ext == "ts":
                out_path.write_bytes(p1.read_bytes() + p2.read_bytes())
            else:
                raw_ts = td_path / "joined.ts"
                raw_ts.write_bytes(p1.read_bytes() + p2.read_bytes())
                r = run_cmd(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(raw_ts), "-c", "copy", str(out_path)])
                if r.returncode != 0:
                    return {"id": vid, "status": "error", "error": r.stderr.strip()}
            return {"id": vid, "status": "ok", "path": str(out_path), "bytes": out_path.stat().st_size}

        if ext == "001":
            full_mkv = td_path / "full.mkv"
            vf = build_flash_vf(size, cues)
            r = run_cmd([
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-f", "lavfi", "-i", f"testsrc2=size={size}:rate=25:duration={dur}",
                "-i", str(wav), "-vf", vf, "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
                "-c:a", "aac", str(full_mkv),
            ])
            if r.returncode != 0:
                return {"id": vid, "status": "error", "error": r.stderr.strip()}
            raw = full_mkv.read_bytes()
            mid = len(raw) // 2
            out_path.write_bytes(raw[:mid])
            out_path.with_suffix(".002").write_bytes(raw[mid:])
            return {"id": vid, "status": "ok", "path": str(out_path), "bytes": len(raw)}

        if ext == "iso":
            # Build a DVD-Video ISO (or VOB-backed ISO) with dvdauthor + hdiutil
            vob_tmp = td_path / "dvd_src.mpg"
            vf = build_flash_vf("720x576", cues)
            r = run_cmd([
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-f", "lavfi", "-i", f"testsrc2=size=720x576:rate=25:duration={dur}",
                "-i", str(wav), "-vf", vf, "-target", "pal-dvd", "-c:a", "ac3", "-b:a", "192k", str(vob_tmp),
            ])
            if r.returncode != 0:
                return {"id": vid, "status": "error", "error": r.stderr.strip()}
            dvd_dir = td_path / "dvd_root"
            env = os.environ.copy()
            env["VIDEO_FORMAT"] = "PAL"
            r1 = subprocess.run(["dvdauthor", "-o", str(dvd_dir), "-t", str(vob_tmp)], env=env, capture_output=True, text=True)
            r2 = subprocess.run(["dvdauthor", "-o", str(dvd_dir), "-T"], env=env, capture_output=True, text=True)
            if r1.returncode != 0 or r2.returncode != 0:
                return {"id": vid, "status": "error", "error": f"dvdauthor failed: {r1.stderr} {r2.stderr}".strip()}
            r3 = run_cmd(["hdiutil", "makehybrid", "-udf", "-udf-volume-name", "OPX_SUB_DVD", "-o", str(out_path), str(dvd_dir)])
            if r3.returncode != 0:
                return {"id": vid, "status": "error", "error": f"hdiutil failed: {r3.stderr.strip()}"}
            return {"id": vid, "status": "ok", "path": str(out_path), "bytes": out_path.stat().st_size}

        if ext == "bluray":
            vf = build_flash_vf("1280x720", cues)
            r = run_cmd([
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-f", "lavfi", "-i", f"testsrc2=size=1280x720:rate=24:duration={dur}",
                "-i", str(wav), "-vf", vf, "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
                "-c:a", "ac3", "-b:a", "192k", "-f", "mpegts", "-mpegts_m2ts_mode", "1", str(out_path),
            ])
            if r.returncode != 0:
                return {"id": vid, "status": "error", "error": r.stderr.strip()}
            return {"id": vid, "status": "ok", "path": str(out_path), "bytes": out_path.stat().st_size}

        if ext in ("m3u8", "mpd"):
            vf = build_flash_vf(size, cues)
            cmd = [
                "ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                "-f", "lavfi", "-i", f"testsrc2=size={size}:rate=25:duration={dur}",
                "-i", str(wav), "-vf", vf, "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
                "-g", "50", "-keyint_min", "50", "-c:a", "aac",
            ]
            if ext == "m3u8":
                if "fmp4" in vid:
                    cmd += ["-f", "hls", "-hls_time", "4", "-hls_playlist_type", "vod", "-hls_segment_type", "fmp4",
                            "-hls_fmp4_init_filename", "init.mp4", "-hls_segment_filename", str(out_path.parent / "seg_%03d.m4s"), str(out_path)]
                else:
                    cmd += ["-f", "hls", "-hls_time", "4", "-hls_playlist_type", "vod", "-output_ts_offset", "3600",
                            "-hls_segment_filename", str(out_path.parent / "seg_%03d.ts"), str(out_path)]
            else:
                cmd += ["-f", "dash", "-seg_duration", "4", "-use_template", "1", "-use_timeline", "1", str(out_path)]
            r = run_cmd(cmd)
            if r.returncode != 0:
                return {"id": vid, "status": "error", "error": r.stderr.strip()}
            # For HLS TS with start_time=3600s, also emit a WebVTT with X-TIMESTAMP-MAP=MPEGTS:324000000,LOCAL:00:00:00.000
            if "xtsmap" in vid:
                vtt_lines = ["WEBVTT", "X-TIMESTAMP-MAP=MPEGTS:324000000,LOCAL:00:00:00.000", ""]
                for s, e, t in cues:
                    vtt_lines += [f"{fmt_vtt_time(s)} --> {fmt_vtt_time(e)}", t, ""]
                (out_path.parent / "subs.vtt").write_text("\n".join(vtt_lines), encoding="utf-8")
            total_b = sum(f.stat().st_size for f in out_path.parent.rglob("*") if f.is_file())
            return {"id": vid, "status": "ok", "path": str(out_path), "bytes": total_b}

        # ---- Standard / parameterized single-command FFmpeg generation ----
        extra_vf = []
        if "anamorphic_sar_16_11" in v["timestamp_features"]:
            extra_vf.append("setsar=16/11")
        if "interlaced_tff" in v["timestamp_features"]:
            extra_vf.append("setfield=tff")
        vf = build_flash_vf(size, cues, extra_vf)

        # Handle elst trim: generate dur+1s and trim 1s with editlist
        src_dur = dur + 1 if any("elst_trim" in f for f in v["timestamp_features"]) else dur
        cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"]

        # Video input
        if "video_delay_plus_500ms" in v["timestamp_features"]:
            cmd += ["-itsoffset", "0.5"]
        cmd += ["-f", "lavfi", "-i", f"testsrc2=size={size}:rate={fps_expr}:duration={src_dur}"]

        # Audio input(s)
        if has_audio:
            if "audio_delay_plus_500ms" in v["timestamp_features"]:
                cmd += ["-itsoffset", "0.5"]
            elif "audio_delay_minus_500ms" in v["timestamp_features"]:
                cmd += ["-itsoffset", "-0.5"]
            cmd += ["-i", str(wav)]
            if v["multi_audio"]:
                cmd += ["-i", str(wav)]

        # Mapping
        if has_audio and v["multi_audio"]:
            cmd += ["-map", "0:v:0", "-map", "1:a:0", "-map", "2:a:0"]
        elif has_audio:
            cmd += ["-map", "0:v:0", "-map", "1:a:0"]
        else:
            cmd += ["-map", "0:v:0"]

        if any("elst_trim" in f for f in v["timestamp_features"]):
            cmd += ["-ss", "1", "-t", str(dur), "-use_editlist", "1"]

        cmd += ["-vf", vf]

        # Video codec defaults (fast presets so 134 videos build quickly!)
        vc = v["video_codec"]
        hint = list(v.get("ffmpeg_hint", []))
        # Strip non-CLI placeholder hints
        hint = [h for h in hint if h not in ("mkvmerge_ordered_chapters", "30s_silence_then_tts", "mix_pink_noise_bgm_with_tts", "alternating_zh_en_tts", "sparse_tts_cues_over_30min")]
        # Strip -vf / -ss / -use_editlist / -itsoffset already applied above
        cleaned_hint = []
        skip_next = False
        for h in hint:
            if skip_next:
                skip_next = False
                continue
            if h in ("-vf", "-ss", "-use_editlist", "-itsoffset", "-vsync", "-top"):
                skip_next = True
                continue
            if h == "bframes=8:b-pyramid=1":
                cleaned_hint.append("bframes=8:b-pyramid=1:rc-lookahead=16")
                continue
            cleaned_hint.append(h)

        if "-c:v" not in cleaned_hint:
            if vc == "h264":
                cleaned_hint = ["-c:v", "libx264", "-preset", "veryfast", "-crf", "28", "-pix_fmt", "yuv420p"] + cleaned_hint
            elif vc == "hevc":
                cleaned_hint = ["-c:v", "libx265", "-preset", "ultrafast", "-crf", "30", "-pix_fmt", "yuv420p"] + cleaned_hint
            elif vc == "av1":
                cleaned_hint = ["-c:v", "libsvtav1", "-preset", "12", "-crf", "36", "-pix_fmt", "yuv420p"] + cleaned_hint
            elif vc == "vp9":
                cleaned_hint = ["-c:v", "libvpx-vp9", "-b:v", "600k", "-deadline", "realtime"] + cleaned_hint
            elif vc == "mpeg2video":
                cleaned_hint = ["-c:v", "mpeg2video", "-b:v", "1500k"] + cleaned_hint
        else:
            # Inject fast encoding presets for libx264 / libx265 / libsvtav1 / libvpx-vp9
            if "libx264" in cleaned_hint and "-preset" not in cleaned_hint:
                cleaned_hint += ["-preset", "veryfast", "-crf", "28"]
            if "libx265" in cleaned_hint and "-preset" not in cleaned_hint:
                cleaned_hint += ["-preset", "ultrafast", "-crf", "30"]
            if "libsvtav1" in cleaned_hint and "-preset" not in cleaned_hint:
                cleaned_hint += ["-preset", "12", "-crf", "36"]
            if "libvpx-vp9" in cleaned_hint and "-deadline" not in cleaned_hint:
                cleaned_hint += ["-deadline", "realtime"]

        if has_audio and "-c:a" not in cleaned_hint and "-c:a:0" not in cleaned_hint and "-an" not in cleaned_hint:
            ac = v["audio_codec"]
            if ac == "aac":
                cleaned_hint += ["-c:a", "aac"]
            elif ac == "opus":
                cleaned_hint += ["-c:a", "libopus"]
            elif ac == "ac3":
                cleaned_hint += ["-c:a", "ac3"]
            elif ac == "mp2":
                cleaned_hint += ["-c:a", "mp2"]
            elif ac == "pcm_s16le":
                cleaned_hint += ["-c:a", "pcm_s16le"]

        if has_audio and (v["audio_codec"] == "vorbis" or ext == "dv") and "-ac" not in cleaned_hint:
            cleaned_hint += ["-ac", "2"]

        # Ensure container format flag when needed
        if ext == "ts" and "-f" not in cleaned_hint:
            cleaned_hint += ["-f", "mpegts"]
        elif ext == "m2ts" and "-f" not in cleaned_hint:
            cleaned_hint += ["-f", "mpegts", "-mpegts_m2ts_mode", "1"]

        # 30-min ASR video: use ultrafast + low crf/gop to keep size & speed small
        if dur >= 1800:
            cleaned_hint += ["-crf", "32", "-g", "240"]

        cmd += cleaned_hint + [str(out_path)]
        r = run_cmd(cmd, timeout=600)
        if r.returncode != 0:
            return {"id": vid, "status": "error", "error": r.stderr.strip(), "cmd": " ".join(cmd)}
        return {"id": vid, "status": "ok", "path": str(out_path), "bytes": out_path.stat().st_size}


def generate_embedded_case(c: dict, video_paths: dict[str, str], sub_dir: pathlib.Path, out_dir: pathlib.Path, videos_map: dict[str, dict], skip_existing: bool = True) -> dict:
    """Mux an independent embedded-subtitle video file (Option 1) via -c:v copy -c:a copy."""
    cid = c["id"]
    vid = c["video_id"]
    v = videos_map[vid]
    src_video = pathlib.Path(video_paths[vid])
    ext = v["ext"]
    dur = v["duration_sec"]
    pattern = c.get("content_pattern", "standard")
    emb_codecs = c["embedded_codecs"]

    # Skip special non-muxable containers like ISO/HLS/DASH (handled directly in stream/disc dir)
    if ext in ("m3u8", "mpd", "iso", "bluray", "001"):
        return {"id": cid, "status": "ok", "path": str(src_video), "bytes": src_video.stat().st_size, "note": "reuses stream/disc container"}

    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{cid}.{ext}"
    if skip_existing and out_path.is_file() and out_path.stat().st_size > 0:
        return {"id": cid, "status": "ok", "path": str(out_path), "bytes": out_path.stat().st_size, "cached": True}

    suffix = f"_{dur}s" if dur != 15 else ""
    srt_file = sub_dir / (f"sub-edge-long-cue-srt.srt" if pattern == "long_cue_2s_to_12s" else f"sub-srt-utf8{suffix}.srt")
    ass_file = sub_dir / f"sub-ass{suffix}.ass"
    vtt_file = sub_dir / f"sub-vtt{suffix}.vtt"
    pgs_file = sub_dir / (f"sub-edge-long-cue-pgs.sup" if pattern == "long_cue_2s_to_12s" else f"sub-pgs{suffix}.sup")
    ttml_file = sub_dir / f"sub-ttml{suffix}.ttml"

    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", str(src_video)]
    maps = ["-map", "0:v"]
    if v["audio_codec"] is not None:
        maps.append("-map")
        maps.append("0:a")

    # When remuxing a video whose PTS already starts at a non-zero offset
    # (e.g. start_time=3600s), shift the subtitle input to match the video's
    # timeline instead of shifting the whole output twice.
    sub_itsoffset: list[str] = []
    if "start_time_3600s" in v["timestamp_features"]:
        sub_itsoffset = ["-itsoffset", "3600"]
    elif "start_time_10s" in v["timestamp_features"]:
        sub_itsoffset = ["-itsoffset", "10"]
    elif "start_time_5s" in v["timestamp_features"]:
        sub_itsoffset = ["-itsoffset", "5"]
    elif "pts_33bit_wraparound" in v["timestamp_features"]:
        sub_itsoffset = ["-itsoffset", "95438"]

    sub_args = []
    for idx, scodec in enumerate(emb_codecs):
        inp_idx = idx + 1
        if scodec == "subrip":
            cmd += [*sub_itsoffset, "-i", str(srt_file)]
            sub_args += [f"-c:s:{idx}", "subrip"]
        elif scodec == "ass":
            cmd += [*sub_itsoffset, "-i", str(ass_file)]
            sub_args += [f"-c:s:{idx}", "ass"]
        elif scodec == "webvtt":
            cmd += [*sub_itsoffset, "-i", str(vtt_file)]
            sub_args += [f"-c:s:{idx}", "webvtt"]
        elif scodec == "mov_text":
            cmd += [*sub_itsoffset, "-i", str(srt_file)]
            sub_args += [f"-c:s:{idx}", "mov_text"]
        elif scodec == "ttml":
            cmd += [*sub_itsoffset, "-i", str(srt_file)]
            sub_args += [f"-c:s:{idx}", "ttml"]
        elif scodec == "hdmv_pgs_subtitle":
            cmd += [*sub_itsoffset, "-i", str(pgs_file)]
            sub_args += [f"-c:s:{idx}", "copy"]
        elif scodec == "dvd_subtitle":
            cmd += [*sub_itsoffset, "-i", str(pgs_file)]
            sub_args += [f"-c:s:{idx}", "dvdsub"]
        elif scodec == "dvb_subtitle":
            cmd += [*sub_itsoffset, "-i", str(pgs_file)]
            sub_args += [f"-c:s:{idx}", "dvbsub"]
        elif scodec == "xsub":
            vobsub_idx = sub_dir / f"sub-vobsub{suffix}.idx"
            cmd += [*sub_itsoffset, "-i", str(vobsub_idx)]
            sub_args += [f"-c:s:{idx}", "xsub"]
        else:
            return {"id": cid, "status": "error", "error": f"Unknown embedded codec: {scodec}"}
        maps += ["-map", f"{inp_idx}:s:0"]

    mux_fmt = []
    if ext == "ts":
        mux_fmt = ["-f", "mpegts"]
    elif ext == "m2ts":
        mux_fmt = ["-f", "mpegts", "-mpegts_m2ts_mode", "1"]
        if "dvb_subtitle" in emb_codecs:
            sub_stream_idx = 2 if v["audio_codec"] is not None else 1
            mux_fmt += ["-streamid", f"{sub_stream_idx}:0x1200"]
    elif ext == "m2t" or ext == "tp":
        mux_fmt = ["-f", "mpegts"]
    elif ext == "mk3d":
        mux_fmt = ["-f", "matroska"]
    elif ext == "m4v":
        mux_fmt = ["-f", "mp4"]
    elif ext == "qt":
        mux_fmt = ["-f", "mov"]
    elif ext in ("divx", "xvid"):
        mux_fmt = ["-f", "avi"]
    elif ext == "vob":
        mux_fmt = ["-f", "vob"]
    elif ext in ("mpg", "mpe"):
        mux_fmt = ["-f", "mpeg"]

    cmd += maps + ["-c:v", "copy"]
    if v["audio_codec"] is not None:
        cmd += ["-c:a", "copy"]
    cmd += sub_args + mux_fmt + [str(out_path)]

    r = run_cmd(cmd)
    if r.returncode != 0:
        return {"id": cid, "status": "error", "error": r.stderr.strip(), "cmd": " ".join(cmd)}
    return {"id": cid, "status": "ok", "path": str(out_path), "bytes": out_path.stat().st_size}


def main() -> int:
    ap = argparse.ArgumentParser(description="Generate subtitle-sync verification assets.")
    ap.add_argument("--manifest", type=pathlib.Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--out", type=pathlib.Path, default=DEFAULT_OUT)
    ap.add_argument("--only", default="", help="Comma-separated globs to filter video IDs")
    ap.add_argument("--workers", type=int, default=max(2, (os.cpu_count() or 4) // 2))
    ap.add_argument("--no-embedded", action="store_true", help="Skip embedded_matrix muxing")
    ap.add_argument("--force", action="store_true", help="Overwrite existing files")
    args = ap.parse_args()

    t0 = time.time()
    doc = json.loads(args.manifest.read_text(encoding="utf-8"))
    out_root = args.out.resolve()
    vid_dir = out_root / "videos"
    sub_dir = out_root / "subtitles"
    emb_dir = out_root / "embedded"
    for d in (vid_dir, sub_dir, emb_dir):
        d.mkdir(parents=True, exist_ok=True)

    patterns = [p.strip() for p in args.only.split(",") if p.strip()]
    videos_list = doc["videos"]
    if patterns:
        videos_list = [v for v in videos_list if any(fnmatch.fnmatch(v["id"], pat) for pat in patterns)]
    videos_map = {v["id"]: v for v in doc["videos"]}

    # 1. Generate all external & negative subtitles (15s + 60s)
    print(f"[1/3] Generating {len(doc['external_subtitles']) + len(doc['negative_subtitles'])} subtitle templates (15s + 60s)...")
    sub_results = {}
    for s in doc["external_subtitles"] + doc["negative_subtitles"]:
        for dur in (15, 60):
            if s.get("content_pattern", "standard") != "standard" and dur == 60:
                continue
            try:
                p = write_subtitle_file(s, sub_dir, duration_sec=dur)
                key = s["id"] if dur == 15 else f"{s['id']}_60s"
                sub_results[key] = {"status": "ok", "path": str(p), "bytes": p.stat().st_size}
            except Exception as e:
                key = s["id"] if dur == 15 else f"{s['id']}_60s"
                sub_results[key] = {"status": "error", "error": str(e)}
    sub_err = [k for k, v in sub_results.items() if v["status"] != "ok"]
    print(f"      Subtitles done: {len(sub_results) - len(sub_err)}/{len(sub_results)} ok")

    # 2. Generate base videos in parallel
    print(f"[2/3] Generating {len(videos_list)} base video assets using {args.workers} workers...")
    vid_results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
        futs = {ex.submit(generate_video_asset, v, vid_dir, not args.force): v["id"] for v in videos_list}
        done = 0
        for fut in concurrent.futures.as_completed(futs):
            res = fut.result()
            vid_results[res["id"]] = res
            done += 1
            if res["status"] != "ok":
                print(f"  [ERR] {res['id']}: {res.get('error', '')[:160]}")
            elif done % 20 == 0 or done == len(videos_list):
                print(f"      Videos progress: {done}/{len(videos_list)}")

    vid_ok = {k: v["path"] for k, v in vid_results.items() if v["status"] == "ok"}
    vid_err = [k for k, v in vid_results.items() if v["status"] != "ok"]
    print(f"      Base videos done: {len(vid_ok)}/{len(videos_list)} ok")

    # 3. Generate independent embedded-subtitle muxed videos (Option 1)
    emb_results = {}
    if not args.no_embedded:
        emb_cases = [c for c in doc["cases"] if c["suite"] == "embedded_matrix" and c["video_id"] in vid_ok]
        print(f"[3/3] Muxing {len(emb_cases)} independent embedded-subtitle videos...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as ex:
            futs = {ex.submit(generate_embedded_case, c, vid_ok, sub_dir, emb_dir, videos_map, not args.force): c["id"] for c in emb_cases}
            done = 0
            for fut in concurrent.futures.as_completed(futs):
                res = fut.result()
                emb_results[res["id"]] = res
                done += 1
                if res["status"] != "ok":
                    print(f"  [ERR] {res['id']}: {res.get('error', '')[:160]}")
                elif done % 50 == 0 or done == len(emb_cases):
                    print(f"      Embedded progress: {done}/{len(emb_cases)}")
        emb_err = [k for k, v in emb_results.items() if v["status"] != "ok"]
        print(f"      Embedded videos done: {len(emb_results) - len(emb_err)}/{len(emb_results)} ok")
    else:
        emb_err = []

    total_bytes = sum(f.stat().st_size for f in out_root.rglob("*") if f.is_file() and f.name != "generated-index.json")
    index = {
        "manifest": str(args.manifest),
        "out_dir": str(out_root),
        "elapsed_sec": round(time.time() - t0, 1),
        "total_bytes": total_bytes,
        "total_mb": round(total_bytes / (1024 * 1024), 2),
        "counts": {
            "subtitles_ok": len(sub_results) - len(sub_err),
            "subtitles_err": len(sub_err),
            "videos_ok": len(vid_ok),
            "videos_err": len(vid_err),
            "embedded_ok": len(emb_results) - len(emb_err),
            "embedded_err": len(emb_err),
        },
        "subtitles": sub_results,
        "videos": vid_results,
        "embedded": emb_results,
    }
    index_path = out_root / "generated-index.json"
    index_path.write_text(json.dumps(index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"\nDone in {index['elapsed_sec']}s | Total disk size: {index['total_mb']} MB | Index: {index_path}")
    return 1 if (sub_err or vid_err or emb_err) else 0


if __name__ == "__main__":
    sys.exit(main())
