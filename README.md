# game_server_framework

基于 skynet 的游戏服务器框架。

## 目录结构

| 目录 | 用途 |
|---|---|
| `etc/` | 运行配置（节点配置、服务配置、配置入口） |
| `datas/` | 游戏数值配置表（策划数据，程序只读，支持热更） |
| `lualib/` | 项目自研的通用 Lua 库：被 require 的代码模块，不绑定具体业务（区别于独立运行的服务） |
| `scripts/` | 构建、初始化、运维脚本 |
| `skynet/` | skynet 子模块（框架运行时） |
| `third_party/` | 第三方依赖（源码/子模块/二进制，尽量不修改、单独升级） |

`service/`、`protos/`、`examples/` 等目录不做占位，后续按需由 `scripts/` 中的初始化脚本创建。
