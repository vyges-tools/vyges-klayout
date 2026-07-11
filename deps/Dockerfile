# Build-env base image: ubuntu:24.04 + KLayout's HEADLESS (Qt-free) build deps.
# NO Qt is installed — that is the whole point. Rebuilt RARELY: only when the
# pinned commit's dependency set changes. Published as
# ghcr.io/vyges-tools/vyges-klayout-deps:<tag>. The per-commit build
# (scripts/build-bundle.sh) runs FROM this image, so releases stay cheap.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# The KLayout commit we will build (its build system + deps).
ARG KL_COMMIT

# Qt-free build deps for KLayout's Python module (db/tl/rdb/pex/lib/lym core + all
# streamers), built via setup.py. NO Qt, NO qmake, NO ruby needed for the module.
# VALIDATED 2026-07-11 (v0.30.9 on ubuntu:24.04): this exact set builds the module.
# (qmake/ruby would only be needed for the OPTIONAL strm* buddy CLIs — not built here.)
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates build-essential \
      python3 python3-dev python3-pip python3-venv python3-wheel \
      zlib1g-dev libexpat1-dev libcurl4-openssl-dev libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone KLayout at the pinned commit so the build system matches the source we
# will build. The tree is left in /klayout for the build stage to reuse.
RUN git clone https://github.com/KLayout/klayout.git /klayout \
 && cd /klayout \
 && git checkout "${KL_COMMIT}"
