#!/usr/bin/env python3
"""Summarise a format test run: report.md next to results.json.

Usage: format_report.py REPORT_DIR DEVICE ENGINE
"""
from __future__ import annotations

import datetime
import json
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def engine_version(device: str, engine: str) -> str:
    if engine == "auto":
        return f"router (RoutedPlayerBackend): {engine_version(device, 'mpv')} / {engine_version(device, 'vlc')}"
    if engine == "mpv":
        info = ROOT / "third_party" / "mpv" / f"{device}-arm64" / "BUILDINFO"
        if info.exists():
            kv = dict(l.split("=", 1) for l in info.read_text(encoding="utf-8").splitlines() if "=" in l)
            return f"libmpv {kv.get('mpv', '?')}, FFmpeg {kv.get('ffmpeg', '?')} (package-ffmpeg)"
        return "libmpv (unknown build)"
    lock = ROOT / "example" / device / "Podfile.lock"
    if lock.exists():
        m = re.search(r"^  - (\w*VLCKit) \(([^)]+)\)", lock.read_text(encoding="utf-8"), re.M)
        if m:
            return f"{m.group(1)} {m.group(2)}"
    return "unknown"


def main() -> int:
    # Windows consoles default to a code page without the report's marks.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    report = pathlib.Path(sys.argv[1])
    device = sys.argv[2]
    engine = sys.argv[3] if len(sys.argv) > 3 else "vlc"
    samples = json.loads((report / "samples.json").read_text(encoding="utf-8"))["samples"]
    # Batch results first, then isolated reruns of the failed samples, which
    # decide; a sample that only failed in its batch is marked.
    results: dict[str, dict] = {}
    for f in [*sorted(report.glob("results-[0-9]*.json")), *sorted(report.glob("results-retry-*.json"))]:
        for r in json.loads(f.read_text(encoding="utf-8"))["results"]:
            first = results.get(r["id"])
            if first is not None and first.get("result") != "passed":
                r["batch_failures"] = first.get("failures") or ["not run"]
            results[r["id"]] = r
    (report / "results.json").write_text(json.dumps({"results": list(results.values())}, indent=1))
    commit = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip() or "unknown"
    dirty = subprocess.run(["git", "-C", str(ROOT), "status", "--porcelain"],
                           capture_output=True, text=True).stdout.strip()
    counts = {"passed": 0, "failed": 0, "not run": 0}
    disturbed = sum(1 for r in results.values() if r.get("result") == "passed" and r.get("batch_failures"))
    rows = []
    for s in samples:
        r = results.get(s["id"], {})
        outcome = r.get("result", "not run")
        counts[outcome] = counts.get(outcome, 0) + 1
        p = s.get("probe") or {}
        m = r.get("metrics") or {}
        codecs = " + ".join(c for c in (p.get("video_codec"), p.get("audio_codec")) if c)
        audio = f"{m['audio_rms']} / {m['audio_hz']} Hz" if "audio_rms" in m else ""
        why = "; ".join(r.get("failures", [])) or (s.get("error") or "")
        if outcome == "passed" and r.get("batch_failures"):
            why = "passed on isolated retry; previous failures: " + "; ".join(r["batch_failures"])
        used = f" ({r['engine'].removeprefix('auto:')})" if engine == "auto" and r.get("engine") else ""
        rows.append(f"| {s['id']}{used} | {', '.join(s.get('linear', []))} | .{s['ext']} | {codecs} | "
                    f"{'✅' if outcome == 'passed' else '❌' if outcome == 'failed' else '⚪'} {outcome} | "
                    f"{m.get('start_ms', '')} | {m.get('frame_diff', '')} | {audio} | {why.replace('|', '/')} |")
    lines = [
        f"# File format playback report ({engine})",
        "",
        f"- Date: {datetime.datetime.now().astimezone().isoformat(timespec='seconds')}",
        f"- Platform: {device}; engine: {engine_version(device, engine)}",
        f"- package-media: {commit}{' (dirty)' if dirty else ''}",
        f"- Passed {counts['passed']}, failed {counts['failed']}, not run {counts['not run']} of {len(samples)}"
        f" ({disturbed} passed on isolated retry)",
        "",
        "| Sample | Linear | Ext | Codecs | Result | Start ms | Frame diff | Audio RMS / Hz | Failures |",
        "|---|---|---|---|---|---|---|---|---|",
        *rows,
        "",
    ]
    (report / "report.md").write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines[:6]))
    print(f"report: {report / 'report.md'}")
    return 0 if counts["failed"] == 0 and counts["not run"] == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
