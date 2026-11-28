#!/usr/bin/env bash
# Versioned material playback regression gate, with independent platform baselines.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
case "$(uname -s)" in
  MINGW*|MSYS*)
    # Native Python keeps manifest/report paths usable by Windows Dart.
    python_bin="${MINGW_PREFIX:-/mingw64}/bin/python.exe"
    [ -x "$python_bin" ] || { echo "MSYS2 native Python is required ($python_bin)" >&2; exit 2; }
    exec "$python_bin" -X utf8 -I "$(cygpath -m "$root/tool/test_materials.py")" "$@"
    ;;
esac
exec python3 -I "$root/tool/test_materials.py" "$@"
