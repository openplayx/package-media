#!/usr/bin/env bash
# File format playback tests for one engine (or auto: the engine router,
# RoutedPlayerBackend, as the app uses it): prepares the samples of
# formats/manifest.json and plays each one through the
# engine's PlayerBackend in the example host app (macOS). Not part of
# `flutter test`; run them when this package changes (see README).
#
# Usage: tool/test_formats.sh [--engine mpv|vlc|auto] [--only ID[,ID|GLOB...]] [--pack]
#                             [--device macos | DEVICE[,DEVICE...]]
# Env:   OPX_SAMPLE_CACHE  sample cache (default ~/.cache/openplayx-libvlc-samples)
#        OPX_REPORT_DIR    report directory (default build/formats/<timestamp>)
#        OPX_PARALLEL      test processes (default 2 on a Mac Studio, else 1). Each
#                          has its own copy of the host app (example-w<N>/, own build
#                          directory) and its own device: macOS/Linux share the host,
#                          simulators and emulators need one --device each.
#        OPX_FORMAT_PACK   material pack for --pack (default ../materials/playback;
#                          its samples are "pack-<issue>-<ext>", e.g. --only 'pack-*')
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
only="" pack="" device="macos" engine="mpv"
while [ $# -gt 0 ]; do
  case "$1" in
    --only) only="$2"; shift 2 ;;
    --pack) pack="${OPX_FORMAT_PACK:-$root/../materials/playback}"; shift ;;
    --device) device="$2"; shift 2 ;;
    --engine) engine="$2"; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
for tool in flutter ffmpeg ffprobe python3; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 2; }
done
cache="${OPX_SAMPLE_CACHE:-$HOME/.cache/openplayx-libvlc-samples}"
report="${OPX_REPORT_DIR:-$root/build/formats/$engine-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$report"
report="$(cd "$report" && pwd)"

# On Windows (MSYS2), Dart and Flutter need Windows paths.
native() { case "$(uname -s)" in MINGW*|MSYS*) cygpath -m "$1" ;; *) printf '%s' "$1" ;; esac; }

echo "== samples ($cache)"
python3 -I "$root/tool/prepare_samples.py" --cache "$cache" --out "$report/samples.json" ${only:+--only "$only"} ${pack:+--pack "$pack"}
case "$(uname -s)" in MINGW*|MSYS*)
  python3 -I - "$report/samples.json" <<'PY'
import json, subprocess, sys
p = sys.argv[1]
data = json.load(open(p))
win = lambda path: subprocess.run(["cygpath", "-m", path], capture_output=True, text=True).stdout.strip()
for s in data["samples"]:
    if s.get("path"):
        s["path"] = win(s["path"])
    if (s.get("expect") or {}).get("frame"):
        s["expect"]["frame"] = win(s["expect"]["frame"])
json.dump(data, open(p, "w"))
PY
;; esac

# The host app is restarted every $batch samples, and any failed sample is
# retried once alone so an isolated failure can be distinguished from a crash.
batch="${OPX_BATCH:-30}"
python3 -I - "$report" "$batch" <<'PY'
import json, pathlib, sys
report, size = pathlib.Path(sys.argv[1]), int(sys.argv[2])
samples = json.loads((report / "samples.json").read_text())["samples"]
for i in range(0, len(samples), size):
    (report / f"samples-{i // size + 1:02d}.json").write_text(json.dumps({"samples": samples[i:i + size]}))
PY

# Android devices cannot read the host's cache: serve it over HTTP (the
# emulator reaches the host as 10.0.2.2) and collect the printed results.
remote=""
if flutter devices --machine 2>/dev/null | python3 -I -c '
import json, sys
dev, text = sys.argv[1], sys.stdin.read()
devices = json.loads(text[text.find("["):]) if "[" in text else []  # skip banners
sys.exit(0 if any(d["id"] == dev and d["targetPlatform"].startswith("android") for d in devices) else 1)
' "${device%%,*}"; then
  remote="http://10.0.2.2:${OPX_SAMPLE_PORT:-8765}"
  python3 -I "$root/tool/serve_samples.py" "${OPX_SAMPLE_PORT:-8765}" "$cache" >/dev/null 2>&1 &
  server=$!
  trap 'kill $server 2>/dev/null' EXIT
fi

# Apple TV simulators: flutter-tvos runs lib/tvos_smoke.dart (no
# integration_test runner); the simulator reads the host's sample paths.
tvos=""
if xcrun simctl list devices 2>/dev/null | grep -F "(${device%%,*})" | grep -q "Apple TV"; then
  tvos="${FLUTTER_TVOS_BIN:-$root/../.toolchains/flutter-tvos/bin/flutter-tvos}"
  [ -x "$tvos" ] || { echo "flutter-tvos not found ($tvos); set FLUTTER_TVOS_BIN" >&2; exit 2; }
fi

# Parallel test processes: worker 1 uses example/, worker N a copy in
# example-w<N>/ (same parent, so its relative path dependencies still
# resolve), each with its own build directory and device.
IFS=, read -r -a devices <<< "$device"
if [ -z "${OPX_PARALLEL:-}" ] && [ "$(uname -s)" = Darwin ] &&
   system_profiler SPHardwareDataType 2>/dev/null | grep -q "Model Name: Mac Studio"; then
  parallel=2
else
  parallel="${OPX_PARALLEL:-1}"
fi
case "${devices[0]}" in macos|linux|windows) ;; *)
  if [ "${#devices[@]}" -lt "$parallel" ]; then
    echo "== $parallel processes need $parallel devices (--device a,b); running ${#devices[@]}"
    parallel="${#devices[@]}"
  fi ;;
esac
# Native libraries are built once, before the processes start: their pod
# install / Gradle runs would otherwise build the same FFmpeg and libmpv
# side by side (the builds are cached, so this is quick when current).
if [ "$parallel" -gt 1 ]; then
  first="${devices[0]}"
  native_platform=""
  if [ "$first" = macos ]; then
    native_platform=macos
  elif [ -n "$remote" ]; then
    abi="$(adb -s "$first" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r')"
    echo "== native libraries (android-$abi)"
    bash "$root/tool/ensure_mpv_android.sh" "$abi" > "$report/native.log" 2>&1 ||
      { echo "native build failed, see $report/native.log" >&2; exit 1; }
  elif xcrun simctl list devices 2>/dev/null | grep -F "($first)" | grep -q "Apple TV"; then
    native_platform=tvos
  elif xcrun simctl list devices 2>/dev/null | grep -qF "($first)"; then
    native_platform=ios
  fi
  if [ -n "$native_platform" ]; then
    echo "== native libraries ($native_platform)"
    { bash "${OPX_FFMPEG_PACKAGE:-$root/../ffmpeg-package}/tool/ensure_ffmpeg_apple.sh" "$native_platform" &&
      bash "$root/tool/ensure_mpv_apple.sh" "$native_platform"; } > "$report/native.log" 2>&1 ||
      { echo "native build failed, see $report/native.log" >&2; exit 1; }
  fi
fi
worker_dir() { [ "$1" -eq 1 ] && echo "$root/example" || echo "$root/example-w$1"; }
worker_device() { local d="${devices[$(( $1 - 1 ))]:-}"; echo "${d:-${devices[0]}}"; }
for ((w = 1; w <= parallel; w++)); do
  dir="$(worker_dir "$w")"
  if [ "$w" -gt 1 ]; then
    mkdir -p "$dir"
    rsync -a --delete --exclude build/ --exclude .dart_tool/ --exclude Pods/ \
      --exclude ephemeral/ "$root/example/" "$dir/"
  fi
  (cd "$dir" && flutter pub get >/dev/null)
done
echo "== $parallel test process(es): $(for ((w = 1; w <= parallel; w++)); do printf '%s ' "$(worker_device "$w")"; done)"
# Remote runs: sample paths (and playlist entries) become host URLs.
to_remote() {
  python3 -I - "$1" "$cache" "$remote" <<'PY'
import json, pathlib, sys
part, cache, remote = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
(cache / "remote").mkdir(exist_ok=True)
def url(path: str) -> str:
    return remote + "/" + str(pathlib.Path(path).relative_to(cache))
data = json.loads(part.read_text())
for s in data["samples"]:
    if s.get("status") != "ok" or s["path"].startswith("http"):
        continue
    path = pathlib.Path(s["path"])
    if s["ext"] in ("pls", "m3u", "asx", "cue", "strm"):
        # Playlist entries point at host paths: copies with sample URLs, next
        # to the samples (cue sheets name their file relatively).
        text = path.read_text().replace((cache / "media").as_uri(), remote + "/media")
        text = text.replace(str(cache / "media"), remote + "/media")
        path = path.with_name(f"{path.stem}.remote{path.suffix}")
        path.write_text(text)
    s["path"] = url(str(path))
    if s.get("expect", {}).get("frame"):
        s["expect"]["frame"] = url(s["expect"]["frame"])
part.write_text(json.dumps(data))
PY
}
# Flutter can leave its macOS integration-test host orphaned after exiting.
# Launch Services may then activate that stale instance instead of the next
# test host, starving the new test of frame callbacks. Only reap orphaned
# hosts from this worker's own build directory; live test processes are kept.
cleanup_macos_host() {
  [ "$1" = macos ] || return 0
  python3 -I - "$2/build/macos/Build/Products/Debug/" <<'PY_CLEANUP'
import os, signal, subprocess, sys
prefix = sys.argv[1]
for row in subprocess.check_output(['ps', '-axo', 'pid=,ppid=,comm='], text=True).splitlines():
    fields = row.strip().split(None, 2)
    if len(fields) != 3:
        continue
    pid, parent, command = fields
    if parent == '1' and command.startswith(prefix) and '.app/Contents/MacOS/' in command:
        try:
            os.kill(int(pid), signal.SIGTERM)
        except ProcessLookupError:
            pass
PY_CLEANUP
}
run_part() {  # samples.json worker
  local device dir
  device="$(worker_device "$2")"
  dir="$(worker_dir "$2")"
  cleanup_macos_host "$device" "$dir"
  [ -z "$remote" ] || to_remote "$1"
  echo "== playback tests ($device, worker $2): $(basename "$1")"
  local log="$report/$(basename "$1" .json).log"
  # A watchdog: flutter test occasionally hangs while attaching to an app on
  # a simulator or device; the batch's samples are then rerun alone.
  local samples_define=(--dart-define=OPX_SAMPLES="$(native "$1")")
  [ -z "$remote" ] || samples_define=(--dart-define=OPX_SAMPLES_B64="$(base64 < "$1" | tr -d '\n')")
  cd "$dir"
  if [ -n "$tvos" ]; then
    "$tvos" run -d "$device" -t lib/tvos_smoke.dart \
      --dart-define=OPX_SAMPLES_B64="$(base64 < "$1" | tr -d '\n')" > "$log" 2>&1 &
  else
    flutter test integration_test/formats_test.dart -d "$device" "${samples_define[@]}" \
      --dart-define=OPX_REPORT="$(native "$report")" --dart-define=OPX_ENGINE="$engine" > "$log" 2>&1 &
  fi
  local pid=$! waited=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 5; waited=$((waited + 5))
    if [ "$waited" -ge "${OPX_BATCH_TIMEOUT:-900}" ]; then
      echo "   batch timed out after ${waited}s"; pkill -P "$pid" 2>/dev/null; kill "$pid" 2>/dev/null; break
    fi
  done
  wait "$pid" 2>/dev/null || true
  cleanup_macos_host "$device" "$dir"
  grep -E '^[0-9]+:[0-9]+ \+[0-9]+.*: [^ ]+$|Some tests failed|All tests passed' "$log" | tail -3 || true
  cat "$log" >> "$report/flutter-w$2.log"
  if [ -n "$tvos" ]; then
    # Base64 chunks printed by lib/tvos_smoke.dart (OPX_CHUNK lines).
    python3 -I - "$log" "$report/$(basename "$1" .json | sed 's/samples/results/').json" <<'PY'
import base64, collections, json, re, sys
chunks = collections.defaultdict(dict)
for line in open(sys.argv[1], errors="replace"):
    m = re.search(r"OPX_CHUNK (\S+) (\d+)/(\d+) ([A-Za-z0-9+/=]+)", line)
    if m:
        chunks[m.group(1)][int(m.group(2))] = (int(m.group(3)), m.group(4))
results = []
for parts in chunks.values():
    n = next(iter(parts.values()))[0]
    if len(parts) == n:
        results.append(json.loads(base64.b64decode("".join(parts[i][1] for i in range(n)))))
open(sys.argv[2], "w").write(json.dumps({"results": results}, indent=1))
PY
  elif [ -n "$remote" ]; then
    # Results printed by the test on the device (OPX_RESULT lines).
    python3 -I - "$log" "$report/$(basename "$1" .json | sed 's/samples/results/').json" <<'PY'
import json, sys
results = [json.loads(line.split("OPX_RESULT ", 1)[1]) for line in open(sys.argv[1], errors="replace") if "OPX_RESULT " in line]
open(sys.argv[2], "w").write(json.dumps({"results": results}, indent=1))
PY
  fi
}
# Batches are dealt to the workers in turn; each worker runs its share in order.
run_worker() {  # worker glob
  local n=0 part
  for part in $2; do
    [ -e "$part" ] || continue
    n=$((n + 1))
    [ $(( (n - 1) % parallel + 1 )) -eq "$1" ] || continue
    run_part "$part" "$1"
    # A lone sample that timed out: flutter test sometimes waits forever for
    # the first frame of a freshly launched app that did not come to the
    # foreground. One more launch.
    case "$part" in *-retry-*)
      if grep -q "TimeoutException after" "${part%.json}.log"; then
        echo "   timed out alone; one more launch"
        run_part "$part" "$1"
      fi ;;
    esac
  done
}
run_all() {
  local pids=() w
  for ((w = 1; w <= parallel; w++)); do run_worker "$w" "$1" & pids+=($!); done
  for w in "${pids[@]}"; do wait "$w" || true; done
}
run_all "$report/samples-[0-9]*.json"

python3 -I - "$report" <<'PY'
import json, pathlib, sys
report = pathlib.Path(sys.argv[1])
samples = {s["id"]: s for s in json.loads((report / "samples.json").read_text())["samples"]}
failed = [r["id"] for f in sorted(report.glob("results-[0-9]*.json"))
          for r in json.loads(f.read_text())["results"] if r.get("result") != "passed"]
ran = {r["id"] for f in report.glob("results-[0-9]*.json") for r in json.loads(f.read_text())["results"]}
failed += [i for i in samples if i not in ran]  # crashed batches
for n, i in enumerate(dict.fromkeys(failed), 1):
    (report / f"samples-retry-{n:02d}.json").write_text(json.dumps({"samples": [samples[i]]}))
PY
run_all "$report/samples-retry-*.json"

status=0

python3 -I "$root/tool/format_report.py" "$report" "${device%%,*}" "$engine" || status=1
exit $status
