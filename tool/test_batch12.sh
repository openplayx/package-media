#!/usr/bin/env bash
# Run package-media macOS integration tests for Batch 1 (.img/.ifo/.nrg/.bin/.bivx/.001)
# and Batch 2 (DTS-HD MA, Dolby Atmos, DTS:X, .adp, .afc).
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
engine="${1:-auto}"
report="${OPX_REPORT_DIR:-$root/build/formats/batch12-$engine-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$report"
report="$(cd "$report" && pwd)"

python3 -I "$root/tool/prepare_batch12_tests.py" --out "$report/samples.json"
cp "$report/samples.json" "$report/samples-01.json"

echo "== Batch 1+2 playback tests (macos, $engine)"
(
  cd "$root/example"
  flutter test integration_test/formats_test.dart -d macos \
    --dart-define=OPX_SAMPLES="$report/samples-01.json" \
    --dart-define=OPX_REPORT="$report" \
    --dart-define=OPX_ENGINE="$engine" > "$report/samples-01.log" 2>&1
) || true
grep -E '^[0-9]+:[0-9]+ \+[0-9]+.*: [^ ]+$|Some tests failed|All tests passed' "$report/samples-01.log" | tail -5 || true

status=0
python3 -I "$root/tool/format_report.py" "$report" macos "$engine" || status=1
exit "$status"
