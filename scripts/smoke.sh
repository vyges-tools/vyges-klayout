#!/usr/bin/env bash
# smoke.sh — prove a built artifact works HEADLESS. Accepts a bundle directory OR a
# docker image ref. For a bundle it runs from a FRESH path to prove relocation.
# Checks: (1) klayout.db imports + a GDS write->read round-trip, (2) NO Qt linkage.
# Usage: scripts/smoke.sh <bundle-dir>|<docker-image>
set -euo pipefail
TARGET="${1:?usage: smoke.sh <bundle-dir>|<docker-image>}"

RT='import klayout.db as db; ly=db.Layout(); c=ly.create_cell("T"); c.shapes(ly.layer(1,0)).insert(db.Box(0,0,100,100)); ly.write("/tmp/kl_smoke.gds"); ly2=db.Layout(); ly2.read("/tmp/kl_smoke.gds"); print("round-trip OK, klayout", db.__version__)'

if [ -d "$TARGET" ]; then
  tmp=$(mktemp -d); cp -a "$TARGET" "$tmp/b"
  PYTHONPATH="$tmp/b/pymod" python3 -c "$RT"
  if find "$tmp/b/pymod" -name '*.so' -exec ldd {} \; 2>/dev/null | grep -qi 'libQt'; then
    echo "ERROR: Qt linkage in module" >&2; rm -rf "$tmp"; exit 1; fi
  echo "no-Qt OK"; rm -rf "$tmp"
else
  docker run --rm "$TARGET" python3 -c "$RT"
  docker run --rm "$TARGET" sh -c 'if ldconfig -p | grep -qi libQt; then echo "ERROR: Qt"; exit 1; else echo "no-Qt OK"; fi'
fi
echo "SMOKE_OK"
