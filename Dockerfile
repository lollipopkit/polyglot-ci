# polyglot-ci: multi-language toolchain image for running install → lint → build → test of any
# repository inside an isolated sandbox.
#
# Security: built from the **Docker Official debian base**, no third-party base image (the sandbox
# runs untrusted repositories' installs and tests). Every toolchain comes from its official
# first-party source at the latest stable (not pinned: the trust anchor is the official source;
# Node is additionally SHA256-verified).
#
# Runtime contract: non-root (e.g. uid 65534), read-only rootfs, writable /workspace and /tmp.
# Everything a toolchain writes at run time (HOME, caches, CARGO_HOME, pip user installs) therefore
# lives under /tmp; the toolchains themselves are root-owned and read-only.
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils unzip zip \
      build-essential pkg-config \
      clang lld llvm \
      python3 python3-pip python3-venv python3-pytest \
      libglu1-mesa \
  && ln -sf /usr/bin/python3 /usr/local/bin/python \
  && ln -sf /usr/bin/pip3 /usr/local/bin/pip \
  && rm -rf /var/lib/apt/lists/*

# Go: latest stable from go.dev (version from go.dev/VERSION).
RUN set -eux; \
    GO_VER="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"; \
    curl -fsSL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tgz; \
    tar -C /usr/local -xzf /tmp/go.tgz; rm /tmp/go.tgz

# Node: latest from nodejs.org (dist/latest) with **SHA256 verification** (SHASUMS256.txt).
RUN set -eux; cd /tmp; \
    curl -fsSLO https://nodejs.org/dist/latest/SHASUMS256.txt; \
    FILE="$(grep -oE 'node-v[0-9.]+-linux-x64\.tar\.xz' SHASUMS256.txt | head -n1)"; \
    curl -fsSLO "https://nodejs.org/dist/latest/${FILE}"; \
    grep " ${FILE}\$" SHASUMS256.txt | sha256sum -c -; \
    tar -C /usr/local --strip-components=1 --no-same-owner -xJf "${FILE}"; \
    rm -f "${FILE}" SHASUMS256.txt; \
    npm i -g pnpm yarn

# Rust: official rustup (latest stable; rustup verifies its own downloads), installed to a shared
# path. Its CARGO_HOME is only used here: at run time CARGO_HOME moves to /tmp (see below), the
# toolchain stays under RUSTUP_HOME and the cargo / rustc proxies on PATH.
RUN set -eux; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh; \
    RUSTUP_HOME=/opt/rust CARGO_HOME=/opt/rust sh /tmp/rustup.sh -y --profile minimal --no-modify-path; \
    rm /tmp/rustup.sh

# Flutter (with Dart): the official github.com/flutter/flutter **stable branch**, artifacts
# precached so a run needs no SDK download. The SDK's own pub dependencies go to a cache inside the
# SDK (flutter checks they exist on every run and would otherwise rewrite the SDK); a repository's
# dependencies go to PUB_CACHE under /tmp. TAR_OPTIONS: the artifact archives carry their build
# machine's uids, which a rootless builder cannot set.
RUN set -eux; \
    export TAR_OPTIONS=--no-same-owner PUB_CACHE=/opt/flutter/.pub-cache; \
    git config --system --add safe.directory '*'; \
    git clone -b stable --depth 1 https://github.com/flutter/flutter.git /opt/flutter; \
    /opt/flutter/bin/flutter --disable-analytics; \
    /opt/flutter/bin/flutter precache; \
    rm -rf /root/.config /root/.dart-tool /root/.flutter

# At run time the SDK is read-only, but bin/flutter and bin/dart rewrite stamps under bin/cache on
# every start (their self-update check) and the tool takes a lock file there. These entry points
# run the precompiled tool and the Dart SDK directly; FLUTTER_ALREADY_LOCKED skips the lock (the
# SDK cannot change, so there is nothing to guard).
RUN set -eux; \
    printf '%s\n' '#!/bin/sh' \
      'export FLUTTER_ROOT=/opt/flutter FLUTTER_ALREADY_LOCKED=true' \
      'exec /opt/flutter/bin/cache/dart-sdk/bin/dart --packages=/opt/flutter/packages/flutter_tools/.dart_tool/package_config.json /opt/flutter/bin/cache/flutter_tools.snapshot --suppress-analytics "$@"' \
      >/usr/local/bin/flutter; \
    ln -s /opt/flutter/bin/cache/dart-sdk/bin/dart /usr/local/bin/dart; \
    chmod 755 /usr/local/bin/flutter

# Root ownership everywhere: upstream archives carry their build machine's uids (flutter's go up to
# 397546), which rootless docker cannot map (it fails to extract the layer).
RUN chown -R root:root /opt /usr/local

# /tmp/.local/bin: console scripts of pip user installs (PIP_USER, HOME=/tmp).
ENV PATH=/tmp/.local/bin:/usr/local/go/bin:/opt/rust/bin:$PATH \
    HOME=/tmp \
    RUSTUP_HOME=/opt/rust \
    CARGO_HOME=/tmp/.cargo \
    GOPATH=/tmp/go GOCACHE=/tmp/go-cache GOFLAGS=-mod=mod \
    PUB_CACHE=/tmp/.pub-cache \
    npm_config_cache=/tmp/.npm \
    PIP_USER=1 PIP_BREAK_SYSTEM_PACKAGES=1 PIP_NO_CACHE_DIR=1

# /workspace exists with mode 1777 so a volume mounted there is writable by the sandbox user.
RUN mkdir -p /workspace && chmod 1777 /workspace
WORKDIR /workspace
# The sandbox decides the user (no USER here); the repository tree is put at /workspace.
CMD ["sleep", "3600"]
