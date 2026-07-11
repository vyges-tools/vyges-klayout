# vyges-klayout

A Vyges-controlled, versioned, **reproducible distribution of headless (Qt-free) KLayout** —
the KLayout Python module (`klayout.db`/`.rdb`/`.pex`/`.lib`/…) with **no Qt, no GUI, no X**, so
a flow gets KLayout's layout-database, GDS/OASIS I/O, and DRC/LVS-scripting power at a fraction
of a full KLayout+Qt install.

Two artifacts per release, **same bytes** in both (binary-first):

- **Relocatable `tar.gz`** — the primary product (~21 MB). Unpack anywhere, put `pymod/` on
  `PYTHONPATH`, `import klayout.db`. This is what gets composed into the Vyges EDA container.
- **Container image** — `ghcr.io/vyges-tools/vyges-klayout` — a convenience/test image wrapping
  the same bundle.

Principles:
- **Rebuild, never fork or vendor.** Build KLayout at a pinned release commit — this repo holds
  only the *build recipe* (CI clones upstream at build time). **Zero source patches.**
- **Headless / Qt-free.** The deliverable is the Python module built by `setup.py` — no Qt, no
  qmake. (The `strm*` buddy CLIs would need qmake and are out of scope.)
- **KLayout-only.** The Vyges `gds-view` renderer and any multi-tool container are composed
  **later, at the `vybox-eda` level** — not here — so this artifact stays a clean GPL-3 distro
  with no Apache code inside.

## Licensing

**KLayout is GPL-3.0-or-later.** This repo's build tooling (Dockerfiles, scripts, workflows) is
**Apache-2.0** (`LICENSE`). Each build product ships KLayout's own license as `LICENSE.KLayout`
plus a `SOURCE_OFFER` (the exact upstream commit that is the *corresponding source* under
GPL-3 §6) and a `manifest.json`.

## Use it

**Tarball:**
```sh
tar xzf vyges-klayout-0.30.9-g<short>-linux-x86_64.tar.gz
source vyges-klayout-0.30.9-g<short>/env.sh      # puts pymod/ on PYTHONPATH
python3 -c 'import klayout.db as db; print(db.__version__)'
```

**Container:**
```sh
docker run --rm ghcr.io/vyges-tools/vyges-klayout:0.30.9 \
  python3 -c 'import klayout.db as db; print(db.__version__)'
```

## Naming & selecting a build

The **KLayout commit hash is the immutable identity**; human tags are pointers to it.

| Tag | Meaning |
|---|---|
| `:sha-<12hex>` | immutable — one commit → one build; never re-pointed |
| `:0.30.9` | a pinned release (frozen), alias to a `sha-<…>` |
| `:latest` | moves to the newest pinned release |

`scripts/which.sh <commit|tag|date|latest>` resolves a build to its image ref + tarball URL
from `index.json`.

## How it's built (validated on ubuntu:24.04)

Single-stage, cheap on free runners — KLayout's Qt-free module has only apt-package deps (no
from-source deps, no Qt, no qmake):

1. Clone KLayout at the pinned commit (`upstream.yaml`).
2. `scripts/build-bundle.sh` → `python3 setup.py build` → assemble the relocatable bundle
   (`pymod/` + `LICENSE.KLayout` + `SOURCE_OFFER` + `env.sh` + `manifest.json`) → **tar.gz**.
   The `.so`s link with `RPATH=$ORIGIN`, so the bundle is relocatable with no wheel step.
3. `scripts/wrap-container.sh` wraps the same bundle into the slim image (asserts **no Qt** and
   that `import klayout.db` works).

## Cut a release / bump the pin

Edit **`upstream.yaml`** (`commit`, `release_tag`, `updated_at`) — the source of truth — then
run the `release` workflow with a `version`. A sync workflow proposes pin bumps via PR when
KLayout publishes a new release tag.
