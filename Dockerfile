# 通用验证镜像(plan.md §28.1)。autofix 交付前在**沙盒**内跑 install→lint→build→test。
# 含 flutter+dart / rust / go / node+pnpm+yarn / python 工具链;大镜像(数 GB),**经 CI 构建推 ghcr**,
# 不在 winnowl 主镜像内(那是瘦身运行时)。沙盒以此为 image、network=package-registry-only(只放行包管理器源)。
#
# 沙盒加固注意(KubernetesSandboxBackend):非 root(uid 65534)+ 只读 rootfs + /workspace|/tmp 为 tmpfs。
# 故各工具链 cache 指向可写路径(HOME=/tmp;pub/cargo/go cache 同理),仓库树挂 /workspace。
FROM ghcr.io/cirruslabs/flutter:stable
USER root
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      git curl ca-certificates build-essential pkg-config \
      python3 python3-pip python3-venv \
  && ln -sf /usr/bin/python3 /usr/local/bin/python \
  && ln -sf /usr/bin/pip3 /usr/local/bin/pip \
  && rm -rf /var/lib/apt/lists/*

# Go
ARG GO_VERSION=1.23.4
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xz

# Node 24 + pnpm/yarn
RUN curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && npm i -g pnpm yarn \
  && rm -rf /var/lib/apt/lists/*

# Rust(rustup minimal;装到共享路径,非 root 也可用)
ENV RUSTUP_HOME=/opt/rust CARGO_HOME=/opt/rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --no-modify-path \
  && chmod -R a+rwX /opt/rust

# 工具链 PATH。cache/HOME 指向沙盒可写的 /tmp(只读 rootfs 下必需);pub/cargo/go cache 同理。
ENV PATH=/usr/local/go/bin:/opt/rust/bin:$PATH \
    HOME=/tmp \
    GOPATH=/tmp/go GOCACHE=/tmp/go-cache GOFLAGS=-mod=mod \
    PUB_CACHE=/tmp/.pub-cache \
    npm_config_cache=/tmp/.npm

WORKDIR /workspace
# 沙盒以非 root(65534)运行本镜像;不设 USER(runAsUser 由 pod securityContext 决定)。
CMD ["sleep", "3600"]
