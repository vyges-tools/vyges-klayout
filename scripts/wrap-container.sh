#!/usr/bin/env bash
# wrap-container.sh — wrap an already-built bundle (build-bundle.sh + attach-gds-view.sh)
# into the slim runtime image. The container carries the SAME bytes as the tarball.
# Env: OUT_DIR (default ./dist), VERSION, SHORT (12-hex commit). IMAGE optional.
set -euo pipefail
OUT_DIR="${OUT_DIR:-./dist}"
: "${VERSION:?set VERSION}"
: "${SHORT:?set SHORT (12-hex short commit)}"
IMAGE="${IMAGE:-ghcr.io/vyges-tools/vyges-klayout}"
NAME="vyges-klayout-${VERSION}-g${SHORT}"

[ -d "$OUT_DIR/$NAME" ] || { echo "ERROR: bundle $OUT_DIR/$NAME not found (run build-bundle.sh + attach-gds-view.sh)"; exit 1; }
[ -x "$OUT_DIR/$NAME/bin/gds-view" ] || { echo "ERROR: gds-view missing from bundle (run attach-gds-view.sh)"; exit 1; }

docker build -f Dockerfile.runtime \
  --build-arg BUNDLE_DIR="$NAME" \
  -t "${IMAGE}:sha-${SHORT}" \
  "$OUT_DIR"

echo "built ${IMAGE}:sha-${SHORT}"
