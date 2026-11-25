#!/usr/bin/env bash
# macOS advanced playback regression (ALL-324/325/329/330/331).
# First: ../openplayx-test/formats/build_advanced.py --tsmuxer PATH --download-dv
# Usage: bash tool/test_advanced.sh [--only 'advanced-bluray,advanced-dvd']
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
report="${OPX_REPORT_DIR:-$root/build/formats/advanced-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$report"
report="$(cd "$report" && pwd)"
python3 -I "$root/tool/prepare_advanced.py" --out "$report/samples-01.json" "$@"
cp "$report/samples-01.json" "$report/samples.json"
cd "$root/example"
status=0
flutter test integration_test/formats_test.dart -d macos \
  --dart-define=OPX_SAMPLES="$report/samples-01.json" \
  --dart-define=OPX_REPORT="$report" --dart-define=OPX_ENGINE=auto \
  > "$report/flutter.log" 2>&1 || status=$?
python3 -I "$root/tool/format_report.py" "$report" macos auto || status=1
exit "$status"
