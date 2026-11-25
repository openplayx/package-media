#!/usr/bin/env bash
# File format playback tests for one engine: prepares the samples of
# package-libvlc's formats/manifest.json and plays each one through the
# engine's PlayerBackend in the example host app (macOS). Not part of
# `flutter test`; run them when this package changes (see README).
#
# Usage: tool/test_formats.sh [--engine mpv|vlc] [--only ID[,ID|GLOB...]] [--pack] [--device macos]
# Env:   OPX_LIBVLC_PACKAGE  package-libvlc checkout (default ../package-libvlc)
# Env:   OPX_SAMPLE_CACHE  sample cache (default ~/.cache/openplayx-libvlc-samples)
#        OPX_REPORT_DIR    report directory (default build/formats/<timestamp>)
#        OPX_FORMAT_PACK   material pack for --pack (default ../openplayx-test/formats;
#                          its samples are "pack-<issue>-<ext>", e.g. --only 'pack-*')
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
only="" pack="" device="macos" engine="mpv"
while [ $# -gt 0 ]; do
  case "$1" in
    --only) only="$2"; shift 2 ;;
    --pack) pack="${OPX_FORMAT_PACK:-$root/../openplayx-test/formats}"; shift ;;
    --device) device="$2"; shift 2 ;;
    --engine) engine="$2"; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done
for tool in flutter ffmpeg ffprobe python3; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 2; }
done
libvlc="$(cd "${OPX_LIBVLC_PACKAGE:-$root/../package-libvlc}" && pwd)"
cache="${OPX_SAMPLE_CACHE:-$HOME/.cache/openplayx-libvlc-samples}"
report="${OPX_REPORT_DIR:-$root/build/formats/$engine-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$report"
report="$(cd "$report" && pwd)"

# On Windows (MSYS2), Dart and Flutter need Windows paths.
native() { case "$(uname -s)" in MINGW*|MSYS*) cygpath -m "$1" ;; *) printf '%s' "$1" ;; esac; }

echo "== samples ($cache)"
python3 -I "$libvlc/tool/prepare_samples.py" --cache "$cache" --out "$report/samples.json" ${only:+--only "$only"} ${pack:+--pack "$pack"}
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

# The host app is restarted every $batch samples, and every failed sample is
# then run once more alone: a player can disturb later players in the same
# process (see README, known issues), so the isolated run decides.
batch="${OPX_BATCH:-6}"
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
' "$device"; then
  remote="http://10.0.2.2:${OPX_SAMPLE_PORT:-8765}"
  python3 -I "$root/tool/serve_samples.py" "${OPX_SAMPLE_PORT:-8765}" "$cache" >/dev/null 2>&1 &
  server=$!
  trap 'kill $server 2>/dev/null' EXIT
fi

# Apple TV simulators: flutter-tvos runs lib/tvos_smoke.dart (no
# integration_test runner); the simulator reads the host's sample paths.
tvos=""
if xcrun simctl list devices 2>/dev/null | grep -F "($device)" | grep -q "Apple TV"; then
  tvos="${FLUTTER_TVOS_BIN:-$root/../.toolchains/flutter-tvos/bin/flutter-tvos}"
  [ -x "$tvos" ] || { echo "flutter-tvos not found ($tvos); set FLUTTER_TVOS_BIN" >&2; exit 2; }
fi

cd "$root/example"
flutter pub get >/dev/null
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
run_part() {
  [ -z "$remote" ] || to_remote "$1"
  echo "== playback tests ($device): $(basename "$1")"
  local log="$report/$(basename "$1" .json).log"
  # A watchdog: flutter test occasionally hangs while attaching to an app on
  # a simulator or device; the batch's samples are then rerun alone.
  local samples_define=(--dart-define=OPX_SAMPLES="$(native "$1")")
  [ -z "$remote" ] || samples_define=(--dart-define=OPX_SAMPLES_B64="$(base64 < "$1" | tr -d '\n')")
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
  grep -E '^[0-9]+:[0-9]+ \+[0-9]+.*: [^ ]+$|Some tests failed|All tests passed' "$log" | tail -3 || true
  cat "$log" >> "$report/flutter.log"
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
for part in "$report"/samples-[0-9]*.json; do run_part "$part"; done

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
for part in "$report"/samples-retry-*.json; do
  [ -e "$part" ] && run_part "$part"
done

status=0

python3 -I "$root/tool/format_report.py" "$report" "$device" "$engine" || status=1
exit $status
