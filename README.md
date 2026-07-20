# polyglot-ci

多语言**工具链容器镜像**,用于在隔离沙盒里对任意仓库跑 `install → lint → build → test`。

从 **Docker Official 基底(`debian:bookworm-slim`)** 自建,**不基于任何第三方基底镜像**(避免供应链攻击 —— 该镜像会跑不可信仓库的构建/测试)。所有工具链取自**官方/第一方源的最新 stable**(不钉版本;Node 额外 SHA256 校验)。

## 工具链

- **Flutter / Dart**（`git clone -b stable github.com/flutter/flutter` + `flutter precache`）
- **Go**（go.dev 最新 stable）
- **Rust**（官方 rustup）
- **Node**（nodejs.org 最新 + SHA256 校验）+ pnpm / yarn
- **Python 3** + pip

## 镜像

- `ghcr.io/lollipopkit/polyglot-ci:latest`
- `ghcr.io/lollipopkit/polyglot-ci:v0.0.<run_number>`（唯一版本，推荐钉版引用）

**public 包**：零私有内容，匿名 pull（无需 pull secret）。

## 运行约定

沙盒常以非 root（如 uid 65534）+ 只读 rootfs 运行;工具链 cache/HOME 指向可写 `/tmp`（见 Dockerfile 的 `HOME`/`GOPATH`/`GOCACHE`/`PUB_CACHE`/`npm_config_cache`）。仓库树挂 `/workspace`。
