#!/usr/bin/env python3
"""Run a platform's versioned material baseline; failures never update it."""
from __future__ import annotations

import argparse
import base64
import collections
import contextlib
import datetime
import fnmatch
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASELINE = ROOT / "formats/material-tests.json"
PLATFORMS = {"macos", "android", "ios", "tvos", "linux", "windows"}
DESKTOP_PLATFORMS = {"macos", "linux", "windows"}
# The launcher uses isolated Python; load only this trusted tool directory.
sys.path.insert(0, str(ROOT / "tool"))
from material_transport import AndroidMaterials, LanMaterials
PREPARERS = {
    "formats": "prepare_samples.py",
    "public": "prepare_public_corpus.py",
    "advanced": "prepare_advanced.py",
    "subtitles_playlists": "prepare_backlog_coverage.py",
    "playlists_asx": "prepare_failed_fixes.py",
    "disc_hd_audio": "prepare_batch12_tests.py",
    "iso": "prepare_iso_tests.py",
}


def key(case: dict) -> tuple[str, str, str]:
    return case["suite"], case["engine"], case["id"]


def _validate_expectation(entry: dict, identity: tuple[str, str, str]) -> None:
    if entry.get("expected") not in {"pass", "allow_failure", "unverified"}:
        raise ValueError(f"invalid baseline case: {identity}")
    if entry["expected"] == "allow_failure" and not str(entry.get("reason", "")).strip():
        raise ValueError(f"allowed failure needs a reason: {identity}")


def read_baseline(path: pathlib.Path, platform: str | None = None) -> dict:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(raw, list):
        target = platform or "macos"
        if target not in PLATFORMS:
            raise ValueError("unsupported baseline schema/platform")
        if not raw or not all(isinstance(row, dict) for row in raw):
            raise ValueError("empty baseline")
        expected_keys = set(raw[0].keys())
        if not {"suite", "engine", "id"}.issubset(expected_keys):
            raise ValueError("baseline rows must include suite, engine, and id")
        table_platforms = sorted(p for p in PLATFORMS if p in expected_keys)
        for p in table_platforms:
            if f"{p}_reason" not in expected_keys:
                raise ValueError(f"missing {p}_reason column in baseline")
        has_properties = "properties" in expected_keys
        has_path = "path" in expected_keys
        expected_prop_keys = None
        if has_properties:
            if not isinstance(raw[0]["properties"], dict):
                raise ValueError("properties must be an object")
            expected_prop_keys = set(raw[0]["properties"].keys())
        seen = set()
        cases = []
        for row in raw:
            if set(row.keys()) != expected_keys:
                raise ValueError(f"inconsistent keys in baseline row: {row.get('id')}")
            if has_path and (not isinstance(row["path"], str) or not row["path"].strip()):
                raise ValueError(f"invalid path in baseline row: {row.get('id')}")
            if has_properties:
                if not isinstance(row["properties"], dict) or set(row["properties"].keys()) != expected_prop_keys:
                    raise ValueError(f"inconsistent properties keys in baseline row: {row.get('id')}")
            identity = key(row)
            if identity in seen:
                raise ValueError(f"duplicate baseline case: {identity}")
            seen.add(identity)
            if row["suite"] not in PREPARERS or row["engine"] not in {"auto", "mpv", "vlc"}:
                raise ValueError(f"invalid baseline case: {identity}")
            for p in table_platforms:
                if not isinstance(row[f"{p}_reason"], str):
                    raise ValueError(f"invalid {p}_reason in baseline row: {identity}")
                _validate_expectation({"expected": row[p], "reason": row[f"{p}_reason"]}, identity)
            if target in table_platforms:
                expected = row[target]
                reason = row[f"{target}_reason"]
            else:
                expected = "pass"
                reason = ""
            resolved = {"suite": row["suite"], "engine": row["engine"], "id": row["id"], "expected": expected}
            if reason:
                resolved["reason"] = reason
            cases.append(resolved)
        return {"platform": target, "cases": cases}
    if isinstance(raw, dict) and raw.get("schema") == 1:
        if raw.get("platform") not in PLATFORMS:
            raise ValueError("unsupported baseline schema/platform")
        if platform and platform != raw["platform"]:
            raise ValueError("--platform does not match the selected baseline")
        seen = set()
        if not raw.get("cases"):
            raise ValueError("empty baseline")
        for case in raw["cases"]:
            identity = key(case)
            if identity in seen:
                raise ValueError(f"duplicate baseline case: {identity}")
            seen.add(identity)
            if case["suite"] not in PREPARERS or case["engine"] not in {"auto", "mpv", "vlc"}:
                raise ValueError(f"invalid baseline case: {identity}")
            _validate_expectation(case, identity)
        return raw
    raise ValueError("unsupported baseline schema/platform")


def fingerprint(baseline: dict) -> str:
    return hashlib.sha256(json.dumps(baseline, sort_keys=True).encode()).hexdigest()


def unexpected_flutter_errors(log_text: str, records: list[dict]) -> bool:
    """A late framework exception cannot be hidden by another allowed failure."""
    failed = {r["id"] for r in records if r.get("result") == "failed"}
    for line in log_text.splitlines():
        plain = re.sub(r"\x1b\[[0-9;]*m", "", line).rstrip()
        if plain.endswith("[E]") and not any(plain.endswith(f"{name} [E]") for name in failed):
            return True
    return False


def evaluate(baseline: dict, results: dict, errors: list[str]) -> dict:
    """An allowed failure must still run. Missing, skipped and corrupt results fail."""
    rows = []
    for case in baseline["cases"]:
        result = results.get(key(case), {})
        actual = result.get("result", "not_run")
        if actual == "passed":
            outcome = {"pass": "passed", "allow_failure": "improved", "unverified": "new_pass"}[case["expected"]]
        elif actual == "failed":
            outcome = {"pass": "regression", "allow_failure": "allowed_failure",
                       "unverified": "unverified_failure"}[case["expected"]]
        else:
            outcome = "missing_or_invalid"
        rows.append({**case, "actual": actual, "outcome": outcome,
                     "failures": result.get("failures", [])})
    counts = dict(collections.Counter(row["outcome"] for row in rows))
    passed = not errors and not any(
        row["outcome"] in {"regression", "missing_or_invalid", "unverified_failure"} for row in rows)
    return {"platform": baseline["platform"], "overall": "passed" if passed else "failed", "counts": counts,
            "errors": errors, "cases": rows}


def collect(baseline: dict, report: pathlib.Path) -> tuple[dict, list[str]]:
    results, errors = {}, []
    selected = {key(c) for c in baseline["cases"]}
    for group in sorted(report.glob("runs/*")):
        metadata = group / "group.json"
        if not metadata.is_file():
            errors.append(f"missing group metadata: {group.name}")
            continue
        meta = json.loads(metadata.read_text())
        if meta.get("platform", "macos") != baseline["platform"]:
            errors.append(f"wrong platform in result group: {group.name}")
            continue
        for path in sorted(group.glob("results-[0-9]*.json")):
            try:
                records = json.loads(path.read_text())["results"]
                if not isinstance(records, list):
                    raise ValueError("results must be a list")
                for record in records:
                    identity = meta["suite"], meta["engine"], record["id"]
                    if identity not in selected:
                        errors.append(f"unexpected result: {identity}")
                    elif identity in results:
                        errors.append(f"duplicate result: {identity}")
                    else:
                        results[identity] = record
            except (ValueError, KeyError, TypeError) as error:
                errors.append(f"invalid result file {path}: {error}")
    status_path = report / "execution.json"
    if not status_path.is_file():
        errors.append("execution.json missing (run interrupted or never completed)")
    else:
        errors.extend(json.loads(status_path.read_text())["errors"])
    return results, errors


def write_report(baseline: dict, report: pathlib.Path) -> bool:
    results, errors = collect(baseline, report)
    summary = evaluate(baseline, results, errors)
    run_meta = json.loads((report / "run.json").read_text())
    summary["device"] = run_meta.get("device", {})
    (report / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n")
    lines = ["# 素材测试总报告", "", f"平台：{baseline['platform']}", "",
             f"设备：{summary['device'].get('name', summary['device'].get('id', 'unknown'))} "
             f"{summary['device'].get('sdk', '')}", "",
             f"整体：**{summary['overall']}**", "",
             "只有全部必须通过项通过，且没有漏跑或执行错误，整体才通过。", "",
             "| 分类 | 数量 |", "|---|---:|",
             *[f"| {name} | {count} |" for name, count in summary["counts"].items()], ""]
    if errors:
        lines += ["执行错误：", "", *[f"- {error}" for error in errors], ""]
    lines += ["| 测试组 | 引擎 | 素材用例 | 基线 | 实际 | 判定 | 失败原因 |",
              "|---|---|---|---|---|---|---|"]
    for row in summary["cases"]:
        reason = "; ".join(row["failures"]).replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {row['suite']} | {row['engine']} | {row['id']} | "
                     f"{row['expected']} | {row['actual']} | {row['outcome']} | {reason} |")
    (report / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Overall: {summary['overall']}; {summary['counts']}")
    print(f"Report: {report / 'report.md'}")
    return summary["overall"] == "passed"


def selected_cases(baseline: dict, args: argparse.Namespace) -> list[dict]:
    return [c for c in baseline["cases"]
            if (not args.suite or c["suite"] in args.suite)
            and (not args.engine or c["engine"] in args.engine)
            and (not args.only or any(fnmatch.fnmatch(c["id"], p) for p in args.only.split(",")))]


def show_list(baseline: dict, cases: list[dict]) -> None:
    print("# 素材测试总入口清单\n")
    print(f"平台：{baseline['platform']}；完整基线 {len(baseline['cases'])} 项。\n")
    totals = collections.Counter(c["expected"] for c in baseline["cases"])
    print(f"必须通过 {totals['pass']} 项；允许失败 {totals['allow_failure']} 项；待验证 {totals['unverified']} 项。")
    print("同一素材在不同引擎下是不同用例，基线不会跨引擎套用。\n")
    print("`pass` 必须通过；`allow_failure` 允许准备或播放失败，仍逐项记录。")
    print("`unverified` 尚无本平台证据；新失败需要分析，会使整体失败，不会自动加入豁免。")
    print("必须通过项的准备失败或播放失败使整体失败；任何漏记结果、崩溃或超时也使整体失败。\n")
    print("历史临时 Jellyfin 网关服务的四项流程检查另需服务环境，详见基线的 `outside_material_scope`。\n")
    print("| 测试组 | 准备入口 | 必须通过 | 允许失败 | 待验证 |")
    print("|---|---|---:|---:|---:|")
    for suite, script in PREPARERS.items():
        counts = collections.Counter(c["expected"] for c in cases if c["suite"] == suite)
        print(f"| {suite} | `tool/{script}` | {counts['pass']} | {counts['allow_failure']} | {counts['unverified']} |")
    print("\n| 测试组 | 引擎 | 用例 | 要求 | 基线依据 |")
    print("|---|---|---|---|---|")
    for c in cases:
        reason = c.get("reason", "").replace("|", "\\|").replace("\n", " ")
        print(f"| {c['suite']} | {c['engine']} | {c['id']} | {c['expected']} | {reason} |")


def prepare(suite: str, report: pathlib.Path, cache: pathlib.Path) -> dict[str, dict]:
    folder = report / "prepared" / suite
    folder.mkdir(parents=True)
    out = folder / "samples.json"
    command = [sys.executable, "-X", "utf8", "-I", str(ROOT / "tool" / PREPARERS[suite]), "--out", str(out)]
    if suite == "formats":
        command += ["--cache", str(cache), "--pack", str(ROOT.parent / "materials/playback")]
    with (folder / "prepare.log").open("w") as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                       check=True, timeout=1800)
    samples = json.loads(out.read_text())["samples"]
    resolved = {s["id"]: s for s in samples}
    if len(resolved) != len(samples):
        raise ValueError(f"duplicate prepared ids in {suite}")
    return resolved


def execute(baseline: dict, cases: list[dict], args: argparse.Namespace, report: pathlib.Path,
            transport: AndroidMaterials | None = None) -> None:
    errors = []
    groups = collections.defaultdict(list)
    for case in cases:
        groups[(case["suite"], case["engine"])].append(case)
    for suite in sorted({c["suite"] for c in cases}):
        print(f"Preparing {suite}...", flush=True)
        try:
            prepared = prepare(suite, report, args.cache.resolve())
        except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
            errors.append(f"{suite}: preparation failed: {error}")
            continue
        for (group_suite, engine), group_cases in sorted(groups.items()):
            if group_suite != suite:
                continue
            folder = report / "runs" / f"{suite}-{engine}"
            folder.mkdir(parents=True)
            (folder / "group.json").write_text(json.dumps({
                "suite": suite, "engine": engine, "platform": baseline["platform"]}))
            samples, preparation_failures = [], []
            for case in group_cases:
                sample = prepared.get(case["id"])
                if sample is None or sample.get("status") != "ok":
                    preparation_failures.append({
                        "id": case["id"], "result": "failed", "stage": "prepare",
                        "failures": [str(sample.get("error") if sample else
                                         "missing from prepared inventory")],
                    })
                else:
                    try:
                        samples.append(transport.sample(sample, folder / "pointers" / case["id"])
                                       if transport else sample)
                    except (OSError, ValueError) as error:
                        preparation_failures.append({"id": case["id"], "result": "failed",
                                                     "stage": "transport", "failures": [str(error)]})
            if preparation_failures and not args.prepare_only:
                (folder / "results-0000.json").write_text(json.dumps({"results": preparation_failures}))
            (folder / "preparation-failures.json").write_text(json.dumps(preparation_failures, indent=2))
            if args.prepare_only:
                required = {c["id"] for c in group_cases if c["expected"] != "allow_failure"}
                errors.extend(f"{suite}/{engine}/{r['id']}: preparation failed"
                              for r in preparation_failures if r["id"] in required)
            for start in range(0, len(samples), args.batch_size):
                batch = samples[start:start + args.batch_size]
                name = f"samples-{start // args.batch_size + 1:04d}"
                manifest = folder / f"{name}.json"
                manifest.write_text(json.dumps({"samples": batch}, indent=2))
                if args.prepare_only:
                    continue
                print(f"Running {suite}/{engine}/{name} ({len(batch)} cases)...", flush=True)
                if baseline["platform"] in DESKTOP_PLATFORMS:
                    sample_define = f"--dart-define=OPX_SAMPLES={manifest}"
                else:
                    encoded = base64.b64encode(manifest.read_bytes()).decode("ascii")
                    sample_define = f"--dart-define=OPX_SAMPLES_B64={encoded}"
                if baseline["platform"] == "tvos":
                    tvos_bin = shutil.which("flutter-tvos") or str(
                        ROOT.parent / ".toolchains/flutter-tvos/bin/flutter-tvos")
                    command = [tvos_bin, "run", "-d", args.device, "-t", "lib/tvos_smoke.dart",
                               sample_define]
                else:
                    command = [shutil.which("flutter") or "flutter", "test", "integration_test/formats_test.dart", "-d", args.device,
                               sample_define,
                               f"--dart-define=OPX_REPORT={folder}", f"--dart-define=OPX_ENGINE={engine}"]
                    if getattr(args, "check_mode", "full") != "full":
                        command.append(f"--dart-define=OPX_CHECK_MODE={args.check_mode}")
                    if getattr(args, "allow_physical_device", False):
                        command.append("--no-uninstall")
                try:
                    with (folder / f"{name}.log").open("w") as log:
                        run = subprocess.run(command, cwd=args.project_dir, stdout=log,
                                             stderr=subprocess.STDOUT, timeout=args.timeout)
                    result_file = folder / f"results-{start // args.batch_size + 1:04d}.json"
                    log_text = (folder / f"{name}.log").read_text(errors="replace")
                    if baseline["platform"] == "tvos":
                        chunks: dict[str, dict[int, tuple[int, str]]] = collections.defaultdict(dict)
                        for line in log_text.splitlines():
                            m = re.search(r"OPX_CHUNK (\S+) (\d+)/(\d+) ([A-Za-z0-9+/=]+)", line)
                            if m:
                                chunks[m.group(1)][int(m.group(2))] = (int(m.group(3)), m.group(4))
                        tvos_results = []
                        for parts in chunks.values():
                            n = next(iter(parts.values()))[0]
                            if len(parts) == n:
                                tvos_results.append(json.loads(
                                    base64.b64decode("".join(parts[i][1] for i in range(n)))))
                        result_file.write_text(json.dumps({"results": tvos_results}, indent=2))
                    elif baseline["platform"] not in DESKTOP_PLATFORMS:
                        mobile_results = [json.loads(line.split("OPX_RESULT ", 1)[1])
                                          for line in log_text.splitlines() if "OPX_RESULT " in line]
                        result_file.write_text(json.dumps({"results": mobile_results}, indent=2))
                    records = json.loads(result_file.read_text())["results"] if result_file.exists() else []
                    # Flutter may exit 1 for an allowed assertion failure. An
                    # unexplained non-zero exit is an execution error instead.
                    teardown_failed = any(
                        "(tearDownAll)" in line and ("[E]" in line or "did not complete" in line)
                        for line in log_text.splitlines())
                    framework_error = unexpected_flutter_errors(log_text, records)
                    if (run.returncode not in (0, 1) or teardown_failed or framework_error or
                            (run.returncode and not any(r.get("result") == "failed" for r in records))):
                        errors.append(f"{suite}/{engine}/{name}: Flutter exited {run.returncode}")
                        if not records or teardown_failed or framework_error or run.returncode not in (0, 1):
                            (report / "execution.json").write_text(json.dumps({"errors": errors}, indent=2))
                            return  # A broken build/device is not a per-material waiver.
                except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
                    errors.append(f"{suite}/{engine}/{name}: execution failed: {error}")
                    (report / "execution.json").write_text(json.dumps({"errors": errors}, indent=2))
                    return
    (report / "execution.json").write_text(json.dumps({"errors": errors}, indent=2))


def resolve_device(platform: str, selected: str | None, allow_physical: bool = False) -> dict:
    if platform == "macos":
        if selected not in {None, "macos"}:
            raise ValueError("macOS baseline requires --device macos")
        return {"id": "macos", "targetPlatform": "darwin"}
    if platform == "linux":
        if selected not in {None, "linux"}:
            raise ValueError("Linux baseline requires --device linux")
        return {"id": "linux", "targetPlatform": "linux"}
    if platform == "windows":
        if selected not in {None, "windows"}:
            raise ValueError("Windows baseline requires --device windows")
        return {"id": "windows", "targetPlatform": "windows"}
    if platform == "tvos":
        sim = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "-j"],
                             check=True, capture_output=True, text=True, timeout=60)
        sim_data = json.loads(sim.stdout)
        tv_devices = [
            d for runtime, devs in sim_data.get("devices", {}).items()
            if "tvOS" in runtime
            for d in devs
            if (d["udid"] == selected if selected else d.get("state") == "Booted")
        ]
        if not tv_devices:
            raise ValueError("no matching booted tvOS simulator; boot one or pass --device <UDID>")
        tv = tv_devices[0]
        return {"id": tv["udid"], "name": tv.get("name", "Apple TV"),
                "targetPlatform": "tvos", "emulator": True}
    run = subprocess.run([shutil.which("flutter") or "flutter", "devices", "--machine"], check=True, capture_output=True,
                         text=True, timeout=120)
    devices = json.loads(run.stdout[run.stdout.index("["):])
    matches = [d for d in devices if d.get("targetPlatform", "").startswith(platform)
               and (d["id"] == selected if selected else d.get("emulator"))]
    if not matches:
        raise ValueError(f"no matching {platform} device; use --device with an available device id")
    device = matches[0]
    if platform == "ios" and not device.get("emulator") and not allow_physical:
        raise ValueError("iOS material transport currently supports simulators; select an iPhone simulator")
    return device


def prepare_project(platform: str, directory: pathlib.Path | None) -> pathlib.Path:
    if directory:
        if not (directory / "pubspec.yaml").is_file():
            raise ValueError(f"invalid Flutter host project: {directory}")
        return directory.resolve()
    if platform == "macos":
        return ROOT / "example"
    destination = ROOT / f"example-w{platform}"
    source_root = ROOT / "example"

    def ignored(directory, names):
        ignored_names = {"build", ".dart_tool", "Pods", "ephemeral", ".symlinks", ".DS_Store",
                         ".flutter-plugins", ".flutter-plugins-dependencies"}
        source = pathlib.Path(directory)
        target = destination / source.relative_to(source_root)
        for lock, config in [("Podfile.lock", "Podfile"), ("pubspec.lock", "pubspec.yaml")]:
            if (lock in names and (target / lock).is_file() and (target / config).is_file()
                    and (source / config).is_file()
                    and (target / config).read_bytes() == (source / config).read_bytes()
                    and (target / lock).stat().st_mtime >= (source / lock).stat().st_mtime):
                # Keep the isolated host's newer resolved lock when its source
                # inputs did not change. Copying an old lock triggers needless
                # native pod rebuilds, possibly blocked by unrelated platforms.
                ignored_names.add(lock)
        return ignored_names

    shutil.copytree(source_root, destination, dirs_exist_ok=True, ignore=ignored)
    return destination


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=sorted(PLATFORMS))
    parser.add_argument("--baseline", type=pathlib.Path)
    parser.add_argument("--device", help="Flutter device id; defaults to an available simulator")
    parser.add_argument("--project-dir", type=pathlib.Path, help="optional isolated Flutter test host")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--list", action="store_true", help="print the baseline as a Markdown list")
    mode.add_argument("--prepare-only", action="store_true", help="prepare without claiming test success")
    mode.add_argument("--check", type=pathlib.Path, help="recompute the gate from a completed run")
    parser.add_argument("--report-dir", type=pathlib.Path)
    parser.add_argument("--cache", type=pathlib.Path, default=ROOT / "build/material-cache")
    parser.add_argument("--suite", action="append", choices=sorted(PREPARERS))
    parser.add_argument("--engine", action="append", choices=["auto", "mpv", "vlc"])
    parser.add_argument("--only", default="", help="diagnostic id globs; omitted cases still fail the full gate")
    parser.add_argument("--batch-size", type=int, default=6)
    parser.add_argument("--timeout", type=int, default=900, help="seconds per Flutter batch")
    parser.add_argument("--allow-physical-device", action="store_true",
                        help="allow running against a physical Android/iOS device (uses LAN HTTP transport on iOS)")
    parser.add_argument("--check-mode", choices=["full", "green_bar"], default="full",
                        help="check mode: 'full' (default) or 'green_bar' (fast snapshot green-bar scan only)")
    args = parser.parse_args()
    try:
        baseline_path = args.baseline or BASELINE
        baseline = read_baseline(baseline_path, platform=args.platform)
        if args.platform and args.platform != baseline["platform"]:
            raise ValueError("--platform does not match the selected baseline")
        if args.batch_size < 1 or args.timeout < 1:
            raise ValueError("batch-size and timeout must be positive")
        cases = selected_cases(baseline, args)
        if not cases:
            raise ValueError("selection matches no cases")
        if args.list:
            show_list(baseline, cases)
            return 0
        if args.check:
            report = args.check.resolve()
            run = json.loads((report / "run.json").read_text())
            if (run.get("baseline_sha256") != fingerprint(baseline) or run.get("mode") != "test" or
                    run.get("platform", "macos") != baseline["platform"]):
                raise ValueError("baseline changed or this was not a playback test run")
            return 0 if write_report(baseline, report) else 1
        if baseline["platform"] in {"macos", "ios", "tvos"} and sys.platform != "darwin" and not args.prepare_only:
            raise ValueError("macOS/iOS/tvOS playback tests require a macOS host")
        device = ({"id": args.device} if args.prepare_only
                  else resolve_device(baseline["platform"], args.device,
                                      allow_physical=args.allow_physical_device))
        if (not args.prepare_only and not args.allow_physical_device
                and baseline.get("environment_kind") in {"emulator", "simulator"}
                and not device.get("emulator")):
            raise ValueError("this baseline requires a simulator/emulator, not a physical device")
        args.device = device["id"]
        args.project_dir = None if args.prepare_only else prepare_project(baseline["platform"], args.project_dir)
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
        report = (args.report_dir or ROOT / "build/material-tests" / f"{baseline['platform']}-{stamp}").resolve()
        report.mkdir(parents=True, exist_ok=False)  # Never reuse stale passing results.
        (report / "run.json").write_text(json.dumps({
            "baseline_sha256": fingerprint(baseline), "platform": baseline["platform"], "device": device,
            "mode": "prepare" if args.prepare_only else "test",
            "selected": len(cases), "total": len(baseline["cases"]),
        }, indent=2))
        (report / "baseline.json").write_text(json.dumps(baseline, ensure_ascii=False, indent=2) + "\n")
        if args.prepare_only:
            context = contextlib.nullcontext()
        elif baseline["platform"] == "android":
            context = AndroidMaterials(args.device)
        elif baseline["platform"] == "ios" and not device.get("emulator"):
            context = LanMaterials(args.device)
        else:
            context = contextlib.nullcontext()
        with context as transport:
            execute(baseline, cases, args, report, transport)
        if args.prepare_only:
            print(f"Prepared only; no playback verdict. See {report / 'execution.json'}")
            return 1 if json.loads((report / "execution.json").read_text())["errors"] else 0
        return 0 if write_report(baseline, report) else 1
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(f"Material test configuration error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
