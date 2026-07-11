#!/usr/bin/env bash
# build-bundle.sh — build HEADLESS (Qt-free) KLayout at $KL_COMMIT (inside the
# deps-env image, where /klayout already exists) and assemble the relocatable
# bundle + tarball into $OUT_DIR.
#
# Binary-first: THIS bundle is the primary artifact; the container
# (Dockerfile.runtime) wraps the same bytes. Relocatable = real binaries + the
# Python module + the non-glibc ldd closure + a wrapper that sets LD_LIBRARY_PATH.
# Host floor: glibc >= 2.39 (the ubuntu:24.04 build base).
#
# GPL boundary: this bundle contains ONLY KLayout (GPL-3) artifacts + its license
# + a SOURCE_OFFER. The Apache-2.0 gds-view binary is added SEPARATELY afterwards
# by scripts/attach-gds-view.sh — it is never built or linked here.
#
# Env: KL_COMMIT (required), VERSION (default "dev"), OUT_DIR (default /out).
set -euo pipefail

: "${KL_COMMIT:?set KL_COMMIT}"
VERSION="${VERSION:-dev}"
OUT_DIR="${OUT_DIR:-/out}"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KL_TREE="${KL_TREE:-/klayout}"
mkdir -p "$OUT_DIR"

echo "== checkout $KL_COMMIT =="
cd "$KL_TREE"
git fetch --depth 1 origin "$KL_COMMIT" 2>/dev/null || git fetch origin
git checkout -q "$KL_COMMIT"

# VALIDATED 2026-07-11 (v0.30.9, ubuntu:24.04, ovs-intelsdn-2): the Qt-free AND
# qmake-free deliverable is the KLayout Python module built by setup.py. Build it
# as a wheel for a clean, relocatable `pip install --target` below. The .so's it
# produces (_db/_tl/_rdb/_pex/_lib/_lym/net_tracer + all streamers) are self-contained.
echo "== build Qt-free python module (pip wheel) =="
python3 -m pip wheel . -w "$OUT_DIR/wheelhouse" --no-deps

# NOTE: the strm* buddy CLIs come from `./build.sh -without-qt`, but that path still
# needs qmake (KLayout's build tool) even for Qt-less libs — so it is OPTIONAL here,
# gated on BUILD_BUDDY=1 + qmake present. The module covers headless I/O + DRC/LVS.

SHORT=$(echo "$KL_COMMIT" | cut -c1-12)
NAME="vyges-klayout-${VERSION}-g${SHORT}"
BUNDLE="$OUT_DIR/$NAME"
echo "== assemble relocatable bundle: $BUNDLE =="
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE"/{bin,pymod}

# Install the built wheel into pymod/ — relocatable: import via PYTHONPATH=$BUNDLE/pymod
# (the klayout/*.so extensions are self-contained; no separate ldd closure needed).
python3 -m pip install --no-deps --no-index --target "$BUNDLE/pymod" \
  "$OUT_DIR"/wheelhouse/klayout-*.whl

# OPTIONAL strm* buddy CLIs — needs qmake (build.sh is qmake-based even for Qt-less libs).
# Skipped unless BUILD_BUDDY=1 and qmake is present; the module already covers headless
# GDS/OASIS I/O + DRC/LVS scripting.
if [ "${BUILD_BUDDY:-0}" = 1 ] && command -v qmake >/dev/null 2>&1; then
  echo "== (optional) buddy tools via build.sh -without-qt =="
  mkdir -p "$BUNDLE"/{libexec,lib}
  ./build.sh -without-qt -noruby -python python3 -libexpat -libpng -libcurl -nolibgit2 \
    -build "$OUT_DIR/kl-build" -bin "$OUT_DIR/kl-bin" -option -j"$(nproc)" || true
  for tool in strm2txt strm2oas strm2gds strmxor strmcmp strmrun; do
    f=$(find "$OUT_DIR/kl-bin" -type f -executable -name "$tool" 2>/dev/null | head -1 || true)
    [ -n "$f" ] || continue
    cp "$f" "$BUNDLE/libexec/$tool"
    printf '#!/bin/sh\nHERE=$(cd "$(dirname "$0")/.." && pwd)\nexport LD_LIBRARY_PATH="$HERE/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\nexec "$HERE/libexec/%s" "$@"\n' "$tool" > "$BUNDLE/bin/$tool"
    chmod +x "$BUNDLE/bin/$tool"
  done
fi

# Ship KLayout's own license (GPL-3 requires it accompany the binary) + a source
# offer pointing at the exact upstream commit that IS the corresponding source.
for lic in LICENSE COPYING LICENSE.txt; do
  [ -f "$KL_TREE/$lic" ] && cp "$KL_TREE/$lic" "$BUNDLE/LICENSE.KLayout" && break
done
cat > "$BUNDLE/SOURCE_OFFER" <<OFFER
This bundle contains a build of KLayout (GPL-3.0-or-later). The complete
corresponding source is the KLayout tree at the exact commit below, plus the
Apache-2.0 build recipe at github.com/vyges-tools/vyges-klayout:

  upstream:  https://github.com/KLayout/klayout
  commit:    ${KL_COMMIT}

  git clone https://github.com/KLayout/klayout && git checkout ${KL_COMMIT}

Vyges will also provide the corresponding source on request for three years.
The KLayout name and trademarks belong to their respective owners; this build is
unaffiliated. See LICENSE.KLayout for the full license text.
OFFER

# Provenance manifest (image_digest + build_date filled by CI post-build;
# gds_view_version filled by attach-gds-view.sh).
if [ -x "$SCRIPTS_DIR/provenance.sh" ]; then
  KL_COMMIT="$KL_COMMIT" VERSION="$VERSION" KL_TREE="$KL_TREE" \
    "$SCRIPTS_DIR/provenance.sh" > "$BUNDLE/manifest.json" || true
fi

echo "BUILD_BUNDLE_OK short=$SHORT name=$NAME (run attach-gds-view.sh, then tar)"
