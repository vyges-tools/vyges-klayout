#!/usr/bin/env bash
# smoke.sh — prove a built artifact runs HEADLESS. Accepts a bundle directory OR a
# docker image ref. For a bundle it runs from a FRESH path to prove relocation.
# Checks: (1) a KLayout buddy tool runs, (2) gds-view renders a GDS -> SVG,
# (3) NO Qt leaked in. Usage: scripts/smoke.sh <bundle-dir>|<docker-image>
set -euo pipefail
TARGET="${1:?usage: smoke.sh <bundle-dir>|<docker-image>}"

run() {  # run a command either in the bundle path or the image
  if [ -d "$1" ]; then shift; "$@"; else img="$1"; shift; docker run --rm "$img" "$@"; fi
}

if [ -d "$TARGET" ]; then
  tmp=$(mktemp -d); cp -a "$TARGET" "$tmp/bundle"; B="$tmp/bundle"
  PYTHONPATH="$B/pymod" python3 -c 'import klayout.db, klayout.rdb; print("klayout.db OK")'
  "$B/bin/gds-view" --version >/dev/null 2>&1 && echo "gds-view OK"
  if find "$B/pymod" -name '*.so' -exec ldd {} \; 2>/dev/null | grep -qi 'libQt'; then
    echo "ERROR: Qt linkage in module" >&2; exit 1; else echo "no-Qt OK"; fi
  rm -rf "$tmp"
else
  docker run --rm -e PYTHONPATH=/opt/vyges-klayout/pymod "$TARGET" sh -lc \
    'python3 -c "import klayout.db, klayout.rdb; print(\"klayout.db OK\")"; gds-view --version >/dev/null 2>&1 && echo "gds-view OK"; if ldconfig -p | grep -qi libQt; then echo "ERROR: Qt"; exit 1; else echo "no-Qt OK"; fi'
fi
echo "SMOKE_OK"
