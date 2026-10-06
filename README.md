# polyglot-ci

多语言**工具链容器镜像**,用于在隔离沙盒里对任意仓库跑 `install → lint → build → test`。

从 **Docker Official 基底(`debian:trixie-slim`)** 自建,**不基于任何第三方基底镜像**(避免供应链攻击 —— 该镜像会跑不可信仓库的构建/测试)。所有工具链取自**官方/第一方源的最新 stable**(不钉版本;Node 额外 SHA256 校验)。

## 工具链

- **Flutter / Dart**（`git clone -b stable github.com/flutter/flutter` + `flutter precache`）
- **Go**（go.dev 最新 stable）
- **Rust**（官方 rustup,stable + clippy / rustfmt）
- **Node**（nodejs.org 最新 + SHA256 校验）+ pnpm / yarn
- **Python 3** + pip + pytest
- **C/C++**:gcc(build-essential)+ clang / lld / llvm(Dart native assets 的 `native_toolchain_c` 在 Linux 上只认 clang)

每周一自动重建(取各官方源当时的最新 stable)。

## 镜像

- `ghcr.io/lollipopkit/polyglot-ci:latest`
- `ghcr.io/lollipopkit/polyglot-ci:v0.0.<run_number>`（唯一版本，推荐钉版引用）

**public 包**：零私有内容，匿名 pull（无需 pull secret）。

## 运行约定

沙盒以非 root（如 uid 65534）+ 只读 rootfs 运行,可写的只有 `/workspace`(仓库树)与 `/tmp`:

- 运行时写的东西都在 `/tmp`:`HOME`、`CARGO_HOME`、`RUSTUP_HOME`、`GOPATH`/`GOCACHE`、`PUB_CACHE`、npm cache、pip user 安装(`PIP_USER=1`)。`/tmp` 要给够(装依赖需要上 GB)。
- 工具链本身归 root、只读;所有文件属主都是 root,rootless docker 也能解压。
- `flutter` / `dart` 是 `/usr/local/bin` 下的入口:直接运行预编译的 flutter tool 与 Dart SDK,跳过 `bin/flutter` 每次启动时改写 SDK 的自更新检查。
- 仓库用 `rust-toolchain.toml` 钉的工具链(版本、额外 target)在首次使用时由 rustup 装进 `/tmp/.rustup`(下载自 `static.rust-lang.org`,走代理时需放行;12 个 target 约 2 GB);镜像自带的 stable 以只读链接的方式放在其中,所以钉 `stable` 又要求额外 target / component 的仓库装不上(会报只读文件系统)。
- 走代理时设 `NO_PROXY=localhost,127.0.0.1,::1`:`flutter test` 的 tester 连本机 websocket。
