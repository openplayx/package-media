#!/usr/bin/env bash
# Verify the 10 fixed ALL-209 failed items on macOS.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
engine="${1:-auto}"
report="${OPX_REPORT_DIR:-$root/build/formats/fixes-$engine-$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$report"
report="$(cd "$report" && pwd)"

python3 -I "$root/tool/prepare_failed_fixes.py" --out "$report/samples.json"
cp "$report/samples.json" "$report/samples-01.json"

echo "== failed-fixes (macos, $engine): samples-01.json"
(
  cd "$root/example"
  flutter test integration_test/formats_test.dart -d macos \
    --dart-define=OPX_SAMPLES="$report/samples-01.json" \
    --dart-define=OPX_REPORT="$report" \
    --dart-define=OPX_ENGINE="$engine" > "$report/samples-01.log" 2>&1
) || true
grep -E '^[0-9]+:[0-9]+ \+[0-9]+.*: [^ ]+$|Some tests failed|All tests passed' "$report/samples-01.log" | tail -3 || true

python3 -I - "$report" <<'PY'
import json, pathlib, sys
report = pathlib.Path(sys.argv[1])
samples = {s["id"]: s for s in json.loads((report / "samples.json").read_text())["samples"]}
ran = {r["id"]: r for f in sorted(report.glob("results-[0-9]*.json")) for r in json.loads(f.read_text())["results"]}
failed = [sid for sid in samples if ran.get(sid, {}).get("result") != "passed"]
for n, sid in enumerate(failed, 1):
    (report / f"samples-retry-{n:02d}.json").write_text(json.dumps({"samples": [samples[sid]]}, indent=2))
PY

for part in "$report"/samples-retry-*.json; do
  [ -e "$part" ] || continue
  log="$report/$(basename "$part" .json).log"
  echo "== failed-fixes retry (macos, $engine): $(basename "$part")"
  (
    cd "$root/example"
    flutter test integration_test/formats_test.dart -d macos \
      --dart-define=OPX_SAMPLES="$part" \
      --dart-define=OPX_REPORT="$report" \
      --dart-define=OPX_ENGINE="$engine" > "$log" 2>&1
  ) || true
  grep -E '^[0-9]+:[0-9]+ \+[0-9]+.*: [^ ]+$|Some tests failed|All tests passed' "$log" | tail -3 || true
done

status=0
python3 -I "$root/tool/format_report.py" "$report" macos "$engine" || status=1
exit "$status"
