# winnowl 通用验证镜像(plan.md §28.1)。autofix 交付前在**沙盒**内跑 install→lint→build→test。
#
# 安全:从 **Docker Official 基底(debian)** 自建,**不用第三方基底镜像**(避免供应链攻击 —— 本沙盒会跑
# 不可信仓库的 install/test)。所有工具链取自**官方/第一方源的最新 stable**(不钉版本 —— 信任锚点即官方源;
# Node 额外 SHA256 校验)。沙盒以非 root(uid 65534)+ 只读 rootfs 运行 → cache/HOME 指向可写 /tmp。
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git xz-utils unzip zip \
      build-essential pkg-config \
      python3 python3-pip python3-venv \
      libglu1-mesa \
  && ln -sf /usr/bin/python3 /usr/local/bin/python \
  && ln -sf /usr/bin/pip3 /usr/local/bin/pip \
  && rm -rf /var/lib/apt/lists/*

# Go —— 官方 go.dev 最新 stable(版本由 go.dev/VERSION 决定)。
RUN set -eux; \
    GO_VER="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"; \
    curl -fsSL "https://go.dev/dl/${GO_VER}.linux-amd64.tar.gz" -o /tmp/go.tgz; \
    tar -C /usr/local -xzf /tmp/go.tgz; rm /tmp/go.tgz

# Node —— 官方 nodejs.org 最新(dist/latest)+ **SHA256 校验**(SHASUMS256.txt sidecar)。
RUN set -eux; cd /tmp; \
    curl -fsSLO https://nodejs.org/dist/latest/SHASUMS256.txt; \
    FILE="$(grep -oE 'node-v[0-9.]+-linux-x64\.tar\.xz' SHASUMS256.txt | head -n1)"; \
    curl -fsSLO "https://nodejs.org/dist/latest/${FILE}"; \
    grep " ${FILE}\$" SHASUMS256.txt | sha256sum -c -; \
    tar -C /usr/local --strip-components=1 -xJf "${FILE}"; \
    rm -f "${FILE}" SHASUMS256.txt; \
    npm i -g pnpm yarn

# Rust —— 官方 rustup(最新 stable;rustup 自身校验其下载)。装到共享路径,非 root 也可用。
ENV RUSTUP_HOME=/opt/rust CARGO_HOME=/opt/rust
RUN set -eux; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh; \
    sh /tmp/rustup.sh -y --profile minimal --no-modify-path; rm /tmp/rustup.sh; \
    chmod -R a+rwX /opt/rust

# Flutter(含 Dart)—— 官方 github.com/flutter/flutter 的 **stable 分支**(最新 stable,官方一手源)。
RUN set -eux; \
    git config --system --add safe.directory '*'; \
    git clone -b stable --depth 1 https://github.com/flutter/flutter.git /opt/flutter; \
    /opt/flutter/bin/flutter --version; \
    chmod -R a+rwX /opt/flutter

ENV PATH=/usr/local/go/bin:/opt/rust/bin:/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH \
    HOME=/tmp \
    GOPATH=/tmp/go GOCACHE=/tmp/go-cache GOFLAGS=-mod=mod \
    PUB_CACHE=/tmp/.pub-cache \
    npm_config_cache=/tmp/.npm

WORKDIR /workspace
# 沙盒 runAsUser 由 pod securityContext 决定(不设 USER);仓库树挂 /workspace。
CMD ["sleep", "3600"]
