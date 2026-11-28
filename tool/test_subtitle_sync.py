#!/usr/bin/env python3
"""Cross-platform automated subtitle-sync regression runner.

Reuses package-media's multi-platform infrastructure (macos, android, ios, tvos,
linux, windows) including AndroidMaterials (adb reverse + HTTP Range + OPX_LOCAL
staging), LanMaterials (physical iOS), prepare_project, and OPX_RESULT collection.

Usage:
  tool/test_subtitle_sync.sh --platform macos --profile smoke
  tool/test_subtitle_sync.sh --platform android --device emulator-5554 --profile core
  tool/test_subtitle_sync.sh --platform ios --profile full
  tool/test_subtitle_sync.sh --platform linux --engine mpv --only '*ts-offset*'
  tool/test_subtitle_sync.sh --platform windows --profile full
"""
from __future__ import annotations

import argparse
import base64
import collections
import contextlib
import datetime
import fnmatch
import json
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tool"))

from material_transport import AndroidMaterials, LanMaterials  # noqa: E402
from test_materials import (  # noqa: E402
    DESKTOP_PLATFORMS,
    PLATFORMS,
    prepare_project,
    resolve_device,
)

DEFAULT_MANIFEST = ROOT / "formats/subtitle-sync-tests.json"
DEFAULT_ASSETS = ROOT.parent / "materials/subtitle-sync"

# Curated smoke subset (~16 high-signal cases covering every critical risk)
SMOKE_CASE_IDS = {
    "ext__v-mp4-h264-aac__sub-srt-utf8",
    "ext__v-mp4-h264-aac__sub-ass",
    "ext__v-mp4-h264-aac__sub-vtt",
    "ext__v-mp4-h264-aac__sub-mks",
    "ext__v-mp4-h264-aac__sub-vobsub",
    "ext__v-mp4-h264-aac__sub-pgs",
    "ext__v-mkv-hevc-opus__sub-srt-utf8",
    "ext__v-ts-offset-3600s__sub-srt-utf8",
    "ext__v-mp4-elst-trim1s__sub-srt-utf8",
    "ext__v-mp4-vfr-15to60__sub-srt-utf8",
    "ext__v-mp4-fps-23_976__sub-srt-utf8",
    "ext__v-mp4-h264-aac__sub-edge-long-cue-srt",
    "emb__v-mkv-h264-aac__subrip",
    "emb__v-mp4-h264-aac__mov_text",
    "emb__v-ts-offset-3600s__dvbsub",
    "neg__v-mp4-h264-aac__neg-srt-offset-plus500ms",
    "neg__v-mp4-h264-aac__neg-srt-offset-minus500ms",
}


def resolve_subtitle_path(sub_id: str | None, dur: int, index: dict) -> str | None:
    if not sub_id:
        return None
    subs = index.get("subtitles", {})
    if dur >= 60 and f"{sub_id}_60s" in subs and subs[f"{sub_id}_60s"].get("status") == "ok":
        return subs[f"{sub_id}_60s"]["path"]
    if sub_id in subs and subs[sub_id].get("status") == "ok":
        return subs[sub_id]["path"]
    return None


def resolve_case_sample(case: dict, doc: dict, index: dict, ops_override: list[str] | None) -> dict:
    vmap = {v["id"]: v for v in doc["videos"]}
    v = vmap[case["video_id"]]
    cid = case["id"]
    suite = case["suite"]

    if suite == "embedded_matrix":
        emb_rec = index.get("embedded", {}).get(cid)
        if not emb_rec or emb_rec.get("status") != "ok":
            return {"id": cid, "suite": suite, "status": "error", "error": f"missing embedded asset for {cid}"}
        video_path = emb_rec["path"]
    else:
        vid_rec = index.get("videos", {}).get(case["video_id"])
        if not vid_rec or vid_rec.get("status") != "ok":
            return {"id": cid, "suite": suite, "status": "error", "error": f"missing video asset {case['video_id']}"}
        video_path = vid_rec["path"]

    sub_path = resolve_subtitle_path(case.get("subtitle_id"), v["duration_sec"], index)
    if case.get("subtitle_id") and not sub_path:
        return {"id": cid, "suite": suite, "status": "error", "error": f"missing subtitle asset {case['subtitle_id']}"}

    ops = ops_override if ops_override is not None else case.get("operation_profiles", ["op_baseline_playback"])
    return {
        "id": cid,
        "suite": suite,
        "video_id": case["video_id"],
        "ext": v["ext"],
        "duration_sec": v["duration_sec"],
        "video_path": video_path,
        "subtitle_path": sub_path,
        "subtitle_delivery": case["subtitle_delivery"],
        "subtitle_format": case["subtitle_format"],
        "subtitle_pipeline": case["subtitle_pipeline"],
        "content_pattern": case.get("content_pattern", "standard"),
        "embedded_codecs": case.get("embedded_codecs", []),
        "operation_profiles": ops,
        "expect_aligned": case.get("expect_aligned", True),
        "tolerance_ms": case.get("tolerance_ms", 100),
        "status": "ok",
    }


def stage_for_transport(sample: dict, transport: AndroidMaterials | None) -> dict:
    """Adapt local video & subtitle paths for Android / physical iOS HTTP transport."""
    if transport is None or sample.get("status") != "ok":
        return sample
    staged = dict(sample)
    device_files = []

    def stage_file(p: pathlib.Path, rel_prefix: str) -> str:
        p = p.resolve()
        name = f"{rel_prefix}/{p.name}"
        device_files.append({"url": transport.url(p), "name": name})
        return f"OPX_LOCAL/{name}"

    vpath = pathlib.Path(sample["video_path"]).resolve()
    ext = sample["ext"]
    if ext in ("m3u8", "mpd"):
        for f in sorted(vpath.parent.rglob("*")):
            if f.is_file():
                rel = f"streams/{vpath.parent.name}/{f.relative_to(vpath.parent).as_posix()}"
                device_files.append({"url": transport.url(f), "name": rel})
        staged["video_path"] = f"OPX_LOCAL/streams/{vpath.parent.name}/{vpath.name}"
    elif ext == "001":
        prefix = vpath.name[:-3]
        for f in sorted(vpath.parent.glob(prefix + "[0-9][0-9][0-9]")):
            stage_file(f, "split")
        staged["video_path"] = f"OPX_LOCAL/split/{vpath.name}"
    elif ext in ("iso", "bluray"):
        staged["video_path"] = stage_file(vpath, "disc")
    else:
        # Regular media can stream directly over HTTP Range!
        staged["video_path"] = transport.url(vpath)

    if sample.get("subtitle_path"):
        sp = pathlib.Path(sample["subtitle_path"]).resolve()
        staged["subtitle_path"] = stage_file(sp, "subs")
        if sp.suffix.lower() == ".idx":
            companion = sp.with_suffix(".sub")
            if companion.is_file():
                stage_file(companion, "subs")

    if device_files:
        staged["device_files"] = device_files
    return staged


def select_cases(doc: dict, args: argparse.Namespace) -> list[dict]:
    cases = doc["cases"]
    # Skip ASR cases unless explicitly requested (ASR requires Whisper pipeline)
    if not args.suite:
        cases = [c for c in cases if c["suite"] != "asr_alignment"]
    else:
        cases = [c for c in cases if c["suite"] in args.suite]

    if args.only:
        pats = [p.strip() for p in args.only.split(",") if p.strip()]
        cases = [c for c in cases if any(fnmatch.fnmatch(c["id"], pat) or fnmatch.fnmatch(c["video_id"], pat) for pat in pats)]
    elif args.profile == "smoke":
        cases = [c for c in cases if c["id"] in SMOKE_CASE_IDS]
    elif args.profile == "core":
        # One representative external format per pipeline + all embedded + all negative
        core_subs = {"sub-srt-utf8", "sub-ass", "sub-vtt", "sub-mks", "sub-microdvd", "sub-vobsub", "sub-pgs", "sub-edge-long-cue-srt"}
        cases = [
            c for c in cases
            if c["suite"] != "external_cartesian" or c.get("subtitle_id") in core_subs
        ]
    return cases


def write_report(report_dir: pathlib.Path, platform: str, engine: str, device: dict, records: list[dict], errors: list[str]) -> bool:
    counts = dict(collections.Counter(r.get("result", "missing") for r in records))
    passed = not errors and counts.get("failed", 0) == 0 and counts.get("missing", 0) == 0 and len(records) > 0
    summary = {
        "platform": platform,
        "engine": engine,
        "device": device,
        "overall": "passed" if passed else "failed",
        "total": len(records),
        "counts": counts,
        "errors": errors,
        "results": records,
    }
    (report_dir / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    lines = [
        "# 字幕同步自动化回归报告",
        "",
        f"- **平台**：`{platform}`",
        f"- **引擎**：`{engine}`",
        f"- **设备**：`{device.get('name', device.get('id', 'unknown'))}`",
        f"- **整体结论**：**{summary['overall']}**",
        "",
        "| 状态 | 数量 |",
        "|---|---:|",
        *[f"| {k} | {v} |" for k, v in counts.items()],
        "",
    ]
    if errors:
        lines += ["## 执行错误", "", *[f"- {e}" for e in errors], ""]
    lines += [
        "## 用例明细",
        "",
        "| 用例 ID | 套件 | 字幕格式 | 预期对齐 | 实际引擎 | 结果 | 失败原因 |",
        "|---|---|---|---|---|---|---|",
    ]
    for r in records:
        reason = "; ".join(r.get("failures", [])).replace("|", "\\|").replace("\n", " ")
        lines.append(
            f"| {r['id']} | {r.get('suite', '')} | {r.get('subtitle_format', '')} | "
            f"{r.get('expect_aligned', True)} | {r.get('engine', engine)} | {r.get('result', 'missing')} | {reason} |"
        )
    (report_dir / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\nOverall ({platform}/{engine}): {summary['overall']} | {counts}")
    print(f"Report: {report_dir / 'report.md'}")
    return passed


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--platform", choices=sorted(PLATFORMS), default="macos")
    ap.add_argument("--engine", choices=["auto", "mpv", "vlc"], default="auto")
    ap.add_argument("--profile", choices=["smoke", "core", "full"], default="smoke")
    ap.add_argument("--suite", action="append", choices=["external_cartesian", "embedded_matrix", "asr_alignment", "negative_control"])
    ap.add_argument("--only", default="", help="Comma-separated globs matching case ID or video ID")
    ap.add_argument("--ops", default="", help="Comma-separated operation_profiles override (e.g. op_baseline_playback,op_seek_stress)")
    ap.add_argument("--manifest", type=pathlib.Path, default=DEFAULT_MANIFEST)
    ap.add_argument("--assets", type=pathlib.Path, default=DEFAULT_ASSETS)
    ap.add_argument("--device", help="Flutter device id")
    ap.add_argument("--project-dir", type=pathlib.Path)
    ap.add_argument("--report-dir", type=pathlib.Path)
    ap.add_argument("--resume", type=pathlib.Path, help="Resume an interrupted report directory, skipping completed batches")
    ap.add_argument("--batch-size", type=int, default=8)
    ap.add_argument("--timeout", type=int, default=900)
    ap.add_argument("--allow-physical-device", action="store_true")
    ap.add_argument("--dry-run", action="store_true", help="Resolve cases and print summary without launching Flutter")
    args = ap.parse_args()

    doc = json.loads(args.manifest.read_text(encoding="utf-8"))
    index_path = args.assets.resolve() / "generated-index.json"
    if not index_path.is_file():
        print(f"Missing {index_path}. Run tool/generate_subtitle_sync_assets.py first.", file=sys.stderr)
        return 2
    index = json.loads(index_path.read_text(encoding="utf-8"))

    selected = select_cases(doc, args)
    if not selected:
        print("No cases matched selection.", file=sys.stderr)
        return 2

    ops_override = [x.strip() for x in args.ops.split(",") if x.strip()] if args.ops else None
    resolved = [resolve_case_sample(c, doc, index, ops_override) for c in selected]
    if args.dry_run:
        ok = sum(1 for r in resolved if r["status"] == "ok")
        print(f"Dry-run ({args.platform}/{args.engine}/{args.profile}): {ok}/{len(resolved)} ready")
        for r in resolved[:10]:
            print(f"  - {r['id']} ({r['subtitle_delivery']}:{r['subtitle_format']}) ops={len(r.get('operation_profiles', []))}")
        if len(resolved) > 10:
            print(f"  ... and {len(resolved) - 10} more")
        return 0

    device = resolve_device(args.platform, args.device, allow_physical=args.allow_physical_device)
    project_dir = prepare_project(args.platform, args.project_dir)

    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    report_dir = (args.resume or args.report_dir or ROOT / "build/subtitle-sync-tests" / f"{args.platform}-{args.engine}-{stamp}").resolve()
    report_dir.mkdir(parents=True, exist_ok=True)

    adb_bin = shutil.which("adb") or str(pathlib.Path.home() / "Library/Android/sdk/platform-tools/adb")

    if args.platform == "android":
        ctx = AndroidMaterials(device["id"])
    elif args.platform == "ios" and not device.get("emulator"):
        ctx = LanMaterials(device["id"])
    else:
        ctx = contextlib.nullcontext()

    all_records: list[dict] = []
    errors: list[str] = []

    with ctx as transport:
        staged = [stage_for_transport(s, transport) for s in resolved]
        for start in range(0, len(staged), args.batch_size):
            batch_idx = start // args.batch_size + 1
            res_file = report_dir / f"results-{batch_idx:04d}.json"
            if args.resume and res_file.is_file():
                try:
                    prev = json.loads(res_file.read_text(encoding="utf-8")).get("results", [])
                    if prev:
                        all_records.extend(prev)
                        continue
                except ValueError:
                    pass

            batch = staged[start:start + args.batch_size]
            batch_file = report_dir / f"samples-{batch_idx:04d}.json"
            batch_file.write_text(json.dumps({"samples": batch}, indent=2, ensure_ascii=False), encoding="utf-8")

            if args.platform in DESKTOP_PLATFORMS:
                sample_define = f"--dart-define=OPX_SUBSYNC_SAMPLES={batch_file}"
            else:
                b64 = base64.b64encode(batch_file.read_bytes()).decode("ascii")
                sample_define = f"--dart-define=OPX_SUBSYNC_SAMPLES_B64={b64}"

            cmd = [
                "flutter", "test", "integration_test/subtitle_sync_test.dart",
                "-d", device["id"],
                sample_define,
                f"--dart-define=OPX_REPORT={report_dir}",
                f"--dart-define=OPX_ENGINE={args.engine}",
            ]
            if args.allow_physical_device:
                cmd.append("--no-uninstall")

            if args.platform == "android":
                # Clean stale adb forward listeners so long multi-batch runs never hit 'Too many open files'.
                subprocess.run([adb_bin, "-s", device["id"], "forward", "--remove-all"], capture_output=True)

            print(f"Running batch {batch_idx} ({len(batch)} cases) on {args.platform}/{device['id']}...", flush=True)
            log_path = report_dir / f"batch-{batch_idx:04d}.log"
            try:
                with log_path.open("w", encoding="utf-8") as lf:
                    proc = subprocess.run(cmd, cwd=project_dir, stdout=lf, stderr=subprocess.STDOUT, timeout=args.timeout)
                log_text = log_path.read_text(encoding="utf-8", errors="replace")
                if args.platform in DESKTOP_PLATFORMS and res_file.is_file():
                    batch_records = json.loads(res_file.read_text(encoding="utf-8"))["results"]
                else:
                    batch_records = [
                        json.loads(line.split("OPX_RESULT ", 1)[1])
                        for line in log_text.splitlines()
                        if "OPX_RESULT " in line
                    ]
                    res_file.write_text(json.dumps({"results": batch_records}, indent=2, ensure_ascii=False), encoding="utf-8")
                all_records.extend(batch_records)
                if proc.returncode not in (0, 1) or not batch_records:
                    errors.append(f"batch-{batch_idx:04d}: flutter exited {proc.returncode} (records={len(batch_records)})")
                    print(f"Stopping early: batch-{batch_idx:04d} failed to execute tests (see {log_path})", file=sys.stderr)
                    break
            except (OSError, subprocess.SubprocessError, ValueError) as exc:
                errors.append(f"batch-{batch_idx:04d}: {exc}")
                break

    ok = write_report(report_dir, args.platform, args.engine, device, all_records, errors)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
