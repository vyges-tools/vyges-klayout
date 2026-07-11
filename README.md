# vyges-klayout

A Vyges-controlled, versioned, **reproducible distribution of headless (Qt-free) KLayout**,
co-packaged with the Vyges **`gds-view`** renderer — so a flow gets KLayout's layout-database,
format-I/O, and DRC/LVS-scripting power **without** the heavy Qt/GUI stack.

- **Rebuild, never fork or vendor.** We build KLayout at a pinned release commit — this repo
  holds only the *build recipe* (no KLayout source in-tree; CI clones upstream at build time).
  **Zero source patches, no unmerged PRs.**
- **Headless / Qt-free.** No `lay`/`edt` GUI, no Qt, no X. The Qt-free core (the `klayout`
  Python module + the `strm*` buddy tools) is a fraction of a full KLayout+Qt install — the
  point is a slim, composable EDA container.
- **Binary-first.** The relocatable bundle is the primary product; the container wraps the
  *same* bytes (slim runtime image, no build tooling).
- **Images:** `ghcr.io/vyges-tools/vyges-klayout` · **Tarballs:** GitHub Releases.

> **Status:** scaffold. The Qt-free build recipe (`scripts/build-bundle.sh`,
> `deps/Dockerfile`) is marked `TODO(spike)` and must be validated on `ubuntu:24.04` before the
> first release. See the internal design doc for rationale.

## Licensing — read this first

**KLayout is GPL-3.0-or-later.** This repo's build tooling (Dockerfiles, scripts, workflows) is
**Apache-2.0** (`LICENSE`). Each built artifact ships KLayout's own license as `LICENSE.KLayout`
plus a `SOURCE_OFFER` (the exact upstream commit that is the *corresponding source* under
GPL-3 §6) and a `manifest.json`.

The Vyges **`gds-view`** binary co-packaged in the runtime image is a **separate Apache-2.0
binary** (`LICENSE.gds-view`), built in its own repo and merely **aggregated** beside the GPL
KLayout binaries — it is **never linked** with any KLayout GPL library, and forms no combined
work with it. Vyges/Apache code must interoperate with KLayout only across the **process/file
boundary** (subprocess + GDS/OASIS/JSON), never by importing/linking KLayout libraries.

## Use it

Consumed via the Vyges CLI (`tools.json`) or a direct pull:

```jsonc
{ "tools": {
    "klayout": { "container": {
      "runtime": "docker",
      "image": "ghcr.io/vyges-tools/vyges-klayout:0.30.9",
      "mounts": ["${PDK_ROOT}:${PDK_ROOT}:ro"]
    } }
    // gds-view rides in the same image as a separate binary (/opt/vyges-klayout/bin/gds-view);
    // loom's gds-view engine resolves to it, or to a standalone gds-view build.
} }
```

## What's in it

| Task | Backed by |
|---|---|
| GDS/OASIS read/write, format conversion | headless KLayout (`strm*` / `klayout.db`) |
| DRC / LVS as a golden oracle | headless KLayout DRC/LVS engines |
| **GDS → SVG/PNG rendering** | **`gds-view` (Rust, Apache-2.0, separate binary)** |

## Naming & selecting a build

The **KLayout commit hash is the immutable identity**; human tags are pointers to it.

| Tag | Meaning |
|---|---|
| `:sha-<12hex>` | immutable — one commit → one build; never re-pointed |
| `:0.30.9` / `:2026.07.0` | a pinned release (frozen), alias to a `sha-<…>` |
| `:latest` | moves to the newest pinned release |

```sh
scripts/which.sh latest      # newest pinned release
scripts/which.sh v0.30.9     # a specific KLayout release
scripts/which.sh 2026-07-11  # a build date
```

## How it's built

Binary-first, two-stage for cheap free-runner CI (mirrors `vyges-openroad`):

1. **`deps/Dockerfile`** → `vyges-klayout-deps` (ubuntu:24.04 + KLayout's **Qt-free** build
   deps — no Qt). Rebuilt **rarely**.
2. **`scripts/build-bundle.sh`** (in the deps image) builds the Qt-free targets and assembles
   the relocatable KLayout bundle (+ `LICENSE.KLayout` + `SOURCE_OFFER`).
3. **`scripts/attach-gds-view.sh`** drops the prebuilt Apache-2.0 `gds-view` binary into the
   bundle as a **separate** executable, then tars it.
4. **`Dockerfile.runtime`** wraps that same bundle into the slim image and **asserts no Qt
   leaked in**.

CI workflows (`deps.yml`, `release.yml`, `nightly.yml`) mirror `vyges-openroad`'s and are added
once the build spike validates the recipe.

## Cut a release / bump the pin

Edit **`upstream.yaml`** (`commit`, `release_tag`, `updated_at`) — the source of truth — then
run the `release` workflow with a `version`. A sync workflow proposes pin bumps via PR when
KLayout publishes a new release tag.
