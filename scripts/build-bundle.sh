#!/usr/bin/env bash
# build-bundle.sh — build HEADLESS (Qt-free) KLayout at $KL_COMMIT and assemble a
# relocatable tar.gz into $OUT_DIR. THE TAR.GZ IS THE PRODUCT.
#
# The Qt-free deliverable is the KLayout Python module (klayout.db/.rdb/.pex/.lib/…)
# built by setup.py — NO Qt, NO qmake. The built .so's link with RPATH=$ORIGIN, so the
# pymod tree is relocatable as-is (no wheel step needed). Validated on ubuntu:24.04
# (v0.30.9): import + GDS round-trip OK, 0 libQt refs, ~80MB (~21MB compressed).
#
# GPL boundary: this bundle contains ONLY KLayout (GPL-3) + its license + a SOURCE_OFFER.
# The Apache-2.0 gds-view renderer and any container are composed LATER at the vybox-eda
# level (which combines vyges-openroad + vyges-klayout + gds-view + loom) — never here.
#
# Env: KL_COMMIT (req), VERSION (default dev), OUT_DIR (default /out),
#      KL_TREE (default /klayout), PYTHON (default python3).
set -euo pipefail
: "${KL_COMMIT:?set KL_COMMIT}"
VERSION="${VERSION:-dev}"
OUT_DIR="${OUT_DIR:-/out}"
KL_TREE="${KL_TREE:-/klayout}"
PYTHON="${PYTHON:-python3}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$OUT_DIR"

echo "== checkout $KL_COMMIT =="
cd "$KL_TREE"
git fetch --depth 1 origin "$KL_COMMIT" 2>/dev/null || git fetch origin
git checkout -q "$KL_COMMIT"

echo "== build Qt-free module (setup.py build) =="
"$PYTHON" setup.py build

MP=$(find "$KL_TREE/build" -maxdepth 2 -type d -name klayout -path '*lib*' | head -1)
[ -n "$MP" ] || { echo "ERROR: built module not found under $KL_TREE/build"; exit 1; }

SHORT=$(echo "$KL_COMMIT" | cut -c1-12)
NAME="vyges-klayout-${VERSION}-g${SHORT}"
B="$OUT_DIR/$NAME"
echo "== assemble relocatable bundle: $B =="
rm -rf "$B"; mkdir -p "$B/pymod"
cp -a "$MP" "$B/pymod/klayout"          # .so's carry RPATH=$ORIGIN → relocatable

# Prove no Qt slipped in (headless invariant).
if find "$B/pymod" -name '*.so' -exec ldd {} \; 2>/dev/null | grep -qi 'libQt'; then
  echo "ERROR: Qt linkage found in module"; exit 1; fi

# GPL-3: ship KLayout's license + a corresponding-source offer.
for lic in LICENSE COPYING LICENSE.txt; do
  [ -f "$KL_TREE/$lic" ] && cp "$KL_TREE/$lic" "$B/LICENSE.KLayout" && break; done
cat > "$B/SOURCE_OFFER" <<OFFER
KLayout (GPL-3.0-or-later). The complete corresponding source is the KLayout tree at
commit ${KL_COMMIT}, plus the Apache-2.0 build recipe at github.com/vyges-tools/vyges-klayout:

  git clone https://github.com/KLayout/klayout && git checkout ${KL_COMMIT}

The KLayout name/trademarks belong to their owners; this build is unaffiliated. See
LICENSE.KLayout for the full license text.
OFFER

# Convenience: source env.sh to put the bundled module on PYTHONPATH.
cat > "$B/env.sh" <<'ENVS'
# usage: source env.sh   ->   python3 -c 'import klayout.db'
HERE=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)
export PYTHONPATH="$HERE/pymod${PYTHONPATH:+:$PYTHONPATH}"
ENVS

# A named launcher so `klayout-py script.py` == python3 with the module on PYTHONPATH.
mkdir -p "$B/bin"
cat > "$B/bin/klayout-py" <<'LAUNCH'
#!/bin/sh
HERE=$(cd "$(dirname "$0")/.." && pwd)
export PYTHONPATH="$HERE/pymod${PYTHONPATH:+:$PYTHONPATH}"
exec python3 "$@"
LAUNCH
chmod +x "$B/bin/klayout-py"

# MCP-friendliness: a self-describing tool descriptor (the container/bundle analog of a
# loom engine's --describe) so the vyges resolve/MCP layer can discover + invoke this tool
# uniformly. Ships in BOTH the tarball and the image; mirrored as com.vyges.tool.* labels.
cat > "$B/vyges-tool.json" <<TOOLJSON
{
  "schema": "vyges-tool-descriptor/1.0",
  "tool": "klayout",
  "version": "${VERSION}",
  "kind": "backing-tool",
  "headless": true,
  "provides": ["gds-io", "oasis-io", "lefdef-io", "layout-db", "drc-oracle", "lvs-oracle"],
  "invoke": { "interpreter": ["python3"], "launcher": "bin/klayout-py",
              "python_module": "klayout.db", "pythonpath": "pymod" },
  "env": { "required": ["PDK_ROOT"], "optional": ["PDK", "STD_CELL_LIBRARY"] },
  "license": "GPL-3.0-or-later",
  "upstream_commit": "${KL_COMMIT}"
}
TOOLJSON

# Copy-paste tools.json wiring for the vyges CLI resolver / MCP layer.
cat > "$B/tools.json.example" <<'TJ'
{ "tools": {
    "klayout": { "container": {
      "runtime": "docker",
      "image": "ghcr.io/vyges-tools/vyges-klayout:latest",
      "entrypoint": "python3"
    } }
} }
TJ

if [ -x "$SCRIPTS_DIR/provenance.sh" ]; then
  KL_COMMIT="$KL_COMMIT" VERSION="$VERSION" KL_TREE="$KL_TREE" \
    "$SCRIPTS_DIR/provenance.sh" > "$B/manifest.json" || true
fi

echo "== tarball (THE PRODUCT) =="
# Arch from the build host (x86_64 or aarch64) — NOT hardcoded, so the same recipe
# produces correctly-labelled bundles on amd64 and arm64 runners.
ARCH="$(uname -m)"
TARBALL="${NAME}-linux-${ARCH}.tar.gz"
tar -C "$OUT_DIR" -czf "$OUT_DIR/${TARBALL}" "$NAME"
du -sh "$B" "$OUT_DIR/${TARBALL}"
echo "BUILD_BUNDLE_OK short=$SHORT arch=$ARCH tarball=${TARBALL}"
