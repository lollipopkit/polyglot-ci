# winnowl-validation

通用**验证沙盒镜像**,用于 [winnowl](https://github.com/lollipopkit/code-review-box) 的 autofix 交付前验证(§28.1)。

autofix 产出补丁后,在**隔离沙盒**里对已打补丁的工作树跑 `install → lint → build → test`,结果作**备注**附到交付的 stacked CR（失败不阻断交付）。本镜像提供各生态工具链，沙盒以它为基础镜像、网络仅放行包管理器源（`package-registry-only`）。

## 工具链

- **Flutter / Dart**（基底 `ghcr.io/cirruslabs/flutter:stable`）
- **Go**、**Rust**（rustup）、**Node**（+ pnpm / yarn）、**Python 3**（+ pip）

## 镜像

- `ghcr.io/lollipopkit/winnowl-validation:latest`
- `ghcr.io/lollipopkit/winnowl-validation:v0.0.<run_number>`（唯一版本，推荐钉版）

**public 包**：零私有内容，匿名 pull（k3s 无需 pull secret）。

## 用法（winnowl runner）

```
VALIDATION_SANDBOX_IMAGE=ghcr.io/lollipopkit/winnowl-validation:v0.0.N
```

沙盒以非 root（uid 65534）+ 只读 rootfs 运行；工具链 cache 指向可写 `/tmp`（见 Dockerfile 的 `HOME`/`GOPATH`/`PUB_CACHE` 等）。
