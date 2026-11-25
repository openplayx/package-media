#!/usr/bin/env bash
# Runs a command in the Linux build/test container with the OpenPlayX
# workspace (sibling checkouts) and the format sample cache mounted at their
# host paths. Flutter is cloned once into a volume at the host's revision.
#   tool/linux/run.sh [--platform linux/amd64] -- <command...>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
workspace="$(cd "$here/../../.." && pwd)"
platform=()
if [ "${1:-}" = --platform ]; then platform=(--platform "$2"); shift 2; fi
[ "${1:-}" = -- ] && shift
image="openplayx/package-media-linux:$(shasum -a 256 "$here/Dockerfile" | cut -c1-12)"
docker image inspect "$image" >/dev/null 2>&1 || docker build ${platform[@]+"${platform[@]}"} -t "$image" "$here"
flutter_rev="$(git -C "$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")" rev-parse HEAD)"
cache="$HOME/.cache/openplayx-libvlc-samples"
mkdir -p "$cache"
exec docker run --rm ${platform[@]+"${platform[@]}"} \
  -v "$workspace:$workspace" -v "$cache:$cache" -v opx-linux-flutter:/opt/flutter \
  -v opx-linux-home:/root -e HOME=/root -e FLUTTER_REV="$flutter_rev" -e OPX_SAMPLE_CACHE="$cache" \
  -w "$workspace" "$image" bash -lc '
    set -e
    if [ ! -x /opt/flutter/bin/flutter ]; then
      git clone -q https://github.com/flutter/flutter.git /opt/flutter
    fi
    git config --global --add safe.directory "*"
    git -C /opt/flutter fetch -q origin "$FLUTTER_REV" 2>/dev/null || true
    git -C /opt/flutter checkout -q --detach "$FLUTTER_REV"
    export PATH=/opt/flutter/bin:$PATH
    flutter config --no-analytics >/dev/null 2>&1 || true
    '"$(printf '%q ' "$@")"
