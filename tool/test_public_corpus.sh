#!/usr/bin/env bash
# Playback integration tests for the public media corpus (ALL-370) in
# ../materials/playback/public/ using package-media's RoutedPlayerBackend
# (or a single engine: mpv / vlc).
#
# Usage: bash tool/test_public_corpus.sh [--engine auto|mpv|vlc] [--source ID[,ID...]] [--only GLOB[,GLOB...]]
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
engine="auto" source_filter="" only="" device="macos"
while [ $# -gt 0 ]; do
  case "$1" in
    --engine) engine="$2"; shift 2 ;;
    --source) source_filter="$2"; shift 2 ;;
    --only) only="$2"; shift 2 ;;
    --device) device="$2"; shift 2 ;;
    *) echo "unknown argument $1" >&2; exit 2 ;;
  esac
done

corpus="${OPX_PUBLIC_CORPUS:-$root/../materials/playback/public}"
report="${OPX_REPORT_DIR:-$root/build/formats/public-$engine-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$report"
report="$(cd "$report" && pwd)"

python3 -I "$root/tool/prepare_public_corpus.py" \
  --corpus "$corpus" \
  --out "$report/samples.json" \
  ${source_filter:+--source "$source_filter"} \
  ${only:+--only "$only"}

batch="${OPX_BATCH:-6}"
python3 -I - "$report" "$batch" <<'PY'
import json, pathlib, sys
report, size = pathlib.Path(sys.argv[1]), int(sys.argv[2])
samples = json.loads((report / "samples.json").read_text())["samples"]
for i in range(0, len(samples), size):
    (report / f"samples-{i // size + 1:02d}.json").write_text(
        json.dumps({"samples": samples[i:i + size]}, indent=2)
    )
PY

run_part() {
  local part="$1"
  local log="$report/$(basename "$part" .json).log"
  echo "== public corpus ($device, $engine): $(basename "$part")"
  (
    cd "$root/example"
    flutter test integration_test/formats_test.dart -d "$device" \
      --dart-define=OPX_SAMPLES="$part" \
      --dart-define=OPX_REPORT="$report" \
      --dart-define=OPX_ENGINE="$engine" > "$log" 2>&1
  ) || true
  grep -E '^[0-9]+:[0-9]+ \+[0-9]+.*: [^ ]+$|Some tests failed|All tests passed' "$log" | tail -3 || true
}

for part in "$report"/samples-[0-9]*.json; do
  [ -e "$part" ] || continue
  run_part "$part"
done

# Retry any failed or crashed sample alone to rule out cross-player state interference.
python3 -I - "$report" <<'PY'
import json, pathlib, sys
report = pathlib.Path(sys.argv[1])
samples = {s["id"]: s for s in json.loads((report / "samples.json").read_text())["samples"]}
ran = {}
for f in sorted(report.glob("results-[0-9]*.json")):
    for r in json.loads(f.read_text())["results"]:
        ran[r["id"]] = r
failed = [sid for sid in samples if ran.get(sid, {}).get("result") != "passed"]
for n, sid in enumerate(failed, 1):
    (report / f"samples-retry-{n:02d}.json").write_text(json.dumps({"samples": [samples[sid]]}, indent=2))
PY

for part in "$report"/samples-retry-*.json; do
  [ -e "$part" ] || continue
  run_part "$part"
done

status=0
python3 -I "$root/tool/format_report.py" "$report" "$device" "$engine" || status=1
exit "$status"
