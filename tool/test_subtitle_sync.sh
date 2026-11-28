#!/usr/bin/env bash
set -euo pipefail
ulimit -n 8192 2>/dev/null || true
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 -I "$ROOT/tool/test_subtitle_sync.py" "$@"
