# game_server_framework

基于 skynet 的游戏服务器框架。

## 目录结构

| 目录 | 用途 |
|---|---|
| `etc/` | 运行配置（节点配置、服务配置、配置入口） |
| `datas/` | 游戏数值配置表（策划数据，程序只读，支持热更） |
| `scripts/launcher/` | 启动入口与纯开发工具（模拟客户端、压测等，不进生产） |
| `scripts/framework/` | 运行时框架：通用工具集 + 通用服务（含监控/调试，生产也要跑） |
| `scripts/game/` | 业务服务 |
| `skynet/` | skynet 子模块（框架运行时） |
| `third_party/` | 第三方依赖（源码/子模块/二进制，尽量不修改、单独升级） |

Docker 开发环境见 [`docker/README.md`](docker/README.md)。

## 快速启动

```powershell
docker compose up -d --build
docker compose exec dev bash -lc "cd /app && bash scripts/launcher/run.sh"
```

看到 `framework booted` 与 `ping service responded: pong` 即说明框架链路正常。
