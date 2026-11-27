#!/usr/bin/env bash
# Versioned material playback regression gate, with independent platform baselines.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 -I "$root/tool/test_materials.py" "$@"
