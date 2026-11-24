#!/usr/bin/env bash
# File format playback tests for one engine: prepares the samples of
# package-libvlc's formats/manifest.json and plays each one through the
# engine's PlayerBackend in the example host app (macOS). Not part of
# `flutter test`; run them when this package changes (see README).
#
# Usage: tool/test_formats.sh [--engine mpv|vlc] [--only ID[,ID|GLOB...]] [--device macos]
# Env:   OPX_LIBVLC_PACKAGE  package-libvlc checkout (default ../package-libvlc)
# Env:   OPX_SAMPLE_CACHE  sample cache (default ~/.cache/openplayx-libvlc-samples)
#        OPX_REPORT_DIR    report directory (default build/formats/<timestamp>)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
only="" device="macos" engine="mpv"
while [ $# -gt 0 ]; do
  case "$1" in
    --only) only="$2"; shift 2 ;;
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

echo "== samples ($cache)"
python3 -I "$libvlc/tool/prepare_samples.py" --cache "$cache" --out "$report/samples.json" ${only:+--only "$only"}

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
dev = sys.argv[1]
sys.exit(0 if any(d["id"] == dev and d["targetPlatform"].startswith("android") for d in json.load(sys.stdin)) else 1)
' "$device"; then
  remote="http://10.0.2.2:${OPX_SAMPLE_PORT:-8765}"
  python3 -I "$root/tool/serve_samples.py" "${OPX_SAMPLE_PORT:-8765}" "$cache" >/dev/null 2>&1 &
  server=$!
  trap 'kill $server 2>/dev/null' EXIT
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
    if s["ext"] in ("pls", "m3u", "asx", "cue"):
        # Playlist entries point at host paths: copies with sample URLs.
        text = path.read_text().replace((cache / "media").as_uri(), remote + "/media")
        text = text.replace(str(cache / "media"), remote + "/media")
        path = cache / "remote" / path.name
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
  local samples_define=(--dart-define=OPX_SAMPLES="$1")
  [ -z "$remote" ] || samples_define=(--dart-define=OPX_SAMPLES_B64="$(base64 < "$1" | tr -d '\n')")
  flutter test integration_test/formats_test.dart -d "$device" "${samples_define[@]}" \
    --dart-define=OPX_REPORT="$report" --dart-define=OPX_ENGINE="$engine" > "$log" 2>&1 &
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
  if [ -n "$remote" ]; then
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
