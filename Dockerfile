# winnowl 通用验证镜像(plan.md §28.1)。autofix 交付前在**沙盒**内跑 install→lint→build→test。
#
# 安全:从 **Docker Official 基底(debian)** 自建,**不用第三方基底镜像**(避免供应链攻击 —— 本沙盒会跑
# 不可信仓库的 install/test)。所有工具链取自**官方/第一方源**(HTTPS + 版本钉定;Node 额外 SHA256 校验)。
# 沙盒以非 root(uid 65534)+ 只读 rootfs 运行 → cache/HOME 指向可写 /tmp。
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

# Go —— 官方 go.dev tarball(HTTPS + 版本钉定)。
ARG GO_VERSION=1.23.4
RUN set -eux; \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tgz; \
    tar -C /usr/local -xzf /tmp/go.tgz; rm /tmp/go.tgz

# Node —— 官方 nodejs.org tarball + **SHA256 校验**(SHASUMS256.txt sidecar)。
ARG NODE_VERSION=22.12.0
RUN set -eux; cd /tmp; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz"; \
    curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt"; \
    grep " node-v${NODE_VERSION}-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c -; \
    tar -C /usr/local --strip-components=1 -xJf "node-v${NODE_VERSION}-linux-x64.tar.xz"; \
    rm -f "node-v${NODE_VERSION}-linux-x64.tar.xz" SHASUMS256.txt; \
    npm i -g pnpm yarn

# Rust —— 官方 rustup(HTTPS;rustup 自身校验其下载)。装到共享路径,非 root 也可用。
ENV RUSTUP_HOME=/opt/rust CARGO_HOME=/opt/rust
RUN set -eux; \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o /tmp/rustup.sh; \
    sh /tmp/rustup.sh -y --profile minimal --no-modify-path; rm /tmp/rustup.sh; \
    chmod -R a+rwX /opt/rust

# Flutter(含 Dart)—— 官方 storage.googleapis.com 发布 tarball(HTTPS + 版本钉定)。
ARG FLUTTER_VERSION=3.24.5
RUN set -eux; \
    curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -o /tmp/flutter.txz; \
    tar -C /opt -xJf /tmp/flutter.txz; rm /tmp/flutter.txz; \
    git config --system --add safe.directory '*'; \
    chmod -R a+rwX /opt/flutter

ENV PATH=/usr/local/go/bin:/opt/rust/bin:/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH \
    HOME=/tmp \
    GOPATH=/tmp/go GOCACHE=/tmp/go-cache GOFLAGS=-mod=mod \
    PUB_CACHE=/tmp/.pub-cache \
    npm_config_cache=/tmp/.npm

WORKDIR /workspace
# 沙盒 runAsUser 由 pod securityContext 决定(不设 USER);仓库树挂 /workspace。
CMD ["sleep", "3600"]
