#!/usr/bin/env bash
# attach-gds-view.sh — drop the prebuilt Vyges gds-view renderer into the bundle
# as a SEPARATE binary, then tar the bundle. This is the deliberate GPL boundary:
# gds-view is Apache-2.0 (© Vyges), built ELSEWHERE (its own repo/CI), and merely
# AGGREGATED beside the GPL-3 KLayout binaries here — never linked with them.
#
# gds-view should be a static binary (musl) so it drops into any base cleanly and
# shares no dynamic libs with KLayout.
#
# Env: BUNDLE (required, path to the assembled bundle dir),
#      GDS_VIEW_BIN (required, path to the prebuilt gds-view executable),
#      GDS_VIEW_VERSION (optional), OUT_DIR (default dirname of BUNDLE).
set -euo pipefail
: "${BUNDLE:?set BUNDLE (assembled bundle dir)}"
: "${GDS_VIEW_BIN:?set GDS_VIEW_BIN (prebuilt gds-view binary)}"
GDS_VIEW_VERSION="${GDS_VIEW_VERSION:-unknown}"
OUT_DIR="${OUT_DIR:-$(dirname "$BUNDLE")}"
NAME="$(basename "$BUNDLE")"

[ -d "$BUNDLE" ] || { echo "ERROR: bundle $BUNDLE not found (run build-bundle.sh)"; exit 1; }
[ -x "$GDS_VIEW_BIN" ] || { echo "ERROR: gds-view binary $GDS_VIEW_BIN not executable"; exit 1; }

install -m 0755 "$GDS_VIEW_BIN" "$BUNDLE/bin/gds-view"
# gds-view carries its own Apache-2.0 license, kept distinct from LICENSE.KLayout.
cat > "$BUNDLE/LICENSE.gds-view" <<LIC
gds-view — © 2026 Vyges. Licensed under the Apache License, Version 2.0.
A separate, independently-built binary aggregated in this bundle; it is NOT
linked with, and forms no combined work with, the GPL-3 KLayout binaries here.
LIC

# Record gds-view provenance alongside KLayout's in the manifest.
if command -v jq >/dev/null 2>&1 && [ -f "$BUNDLE/manifest.json" ]; then
  jq --arg v "$GDS_VIEW_VERSION" '.gds_view_version=$v' "$BUNDLE/manifest.json" \
    > "$BUNDLE/manifest.json.tmp" && mv "$BUNDLE/manifest.json.tmp" "$BUNDLE/manifest.json"
fi

echo "== tarball =="
tar -C "$OUT_DIR" -czf "$OUT_DIR/${NAME}-linux-x86_64.tar.gz" "$NAME"
du -sh "$BUNDLE" "$OUT_DIR/${NAME}-linux-x86_64.tar.gz"
echo "ATTACH_OK gds-view=$GDS_VIEW_VERSION name=$NAME"
