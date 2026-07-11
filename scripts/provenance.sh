#!/usr/bin/env bash
# provenance.sh — emit manifest.json for the commit being built. Run inside the
# build tree (/klayout present). CI fills image_digest + build_date; attach-gds-view.sh
# fills gds_view_version.
# Env: KL_COMMIT (required), VERSION (optional), KL_TREE (default /klayout).
set -euo pipefail
: "${KL_COMMIT:?set KL_COMMIT}"
VERSION="${VERSION:-dev}"
KL_TREE="${KL_TREE:-/klayout}"
TAG=$(git -C "$KL_TREE" describe --tags --exact-match "$KL_COMMIT" 2>/dev/null || echo "")

cat <<JSON
{
  "schema": "vyges-klayout-manifest/1.0",
  "version": "${VERSION}",
  "upstream_commit": "${KL_COMMIT}",
  "release_tag": "${TAG}",
  "base_image": "ubuntu:24.04",
  "qt": "none",
  "license": "GPL-3.0-or-later",
  "gds_view_version": null,
  "image_digest": null,
  "build_date": null
}
JSON
