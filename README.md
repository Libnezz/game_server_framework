# game_server_framework

基于 skynet 的游戏服务器框架。

## 目录结构

| 目录 | 用途 |
|---|---|
| `etc/` | 运行配置（节点配置、服务配置、配置入口） |
| `datas/` | 游戏数值配置表（策划数据，程序只读，支持热更） |
| `scripts/framework/` | 运行时框架：`services/` 通用服务（configservice、protoservice、logservice），`utils/` 通用方法与接口（stringutils 等工具 + config/proto/log 服务接口），根目录（main 启动编排入口、startup 启动清单） |
| `scripts/game/` | 业务：`modules/` 业务服务模块，`managers/` 业务管理器，`constants/` 常量，`protos/` 协议文件 |
| `skynet/` | skynet 子模块（框架运行时） |
| `third_party/` | 第三方依赖（源码/子模块/二进制，尽量不修改、单独升级） |

进程启动层（skynet 二进制 + 配置 + 自带 bootstrap/launcher）由 skynet 承担，项目不单独做启动层；`run.sh` 只是便捷启动命令。Docker 开发环境见 [`docker/README.md`](docker/README.md)。

## 快速启动

```powershell
docker compose up -d --build
docker compose exec dev bash -lc "cd /app && bash run.sh"
```

看到 `framework booted` 与 `echo service responded: framework alive` 即说明框架链路正常。

### 启动编排

框架服务通过 [`scripts/framework/startup.lua`](scripts/framework/startup.lua) 清单按依赖顺序启动（支持性服务 → 基础通用服务 → 业务服务）；数值配置表放在 `datas/`，由 `configservice` 服务加载进只读共享数据，支持热更。

协议文件（protobuf）放在 `scripts/game/protos/`，由 `protoservice` 服务统一加载校验（lua-protobuf 解析，schema 按服务 VM 独立持有）；日志由 `logservice` 统一输出时间戳，业务侧用 `log` 工具（级别过滤）。
