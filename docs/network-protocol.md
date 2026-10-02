# WebSocket NetworkPacket 约定

2026-10-02 实现更新：非经济探索进度的两个已认证协议已加入运行时，独立MySQL文档、首次创建/CAS、重复点幂等、并发与重启恢复已验证，见 [exploration-progress.md](exploration-progress.md)。设计原稿见 [online-exploration-write-plan.md](online-exploration-write-plan.md)。人物档案/钱包仍只读，没有经济奖励；空间行为仍由开发客户端声明。

2026-09-30 后续状态：完整 PlayerProfileResponse 已由 MySQL `player_profiles` 文档持久化并校验读取；开发种子仅在首次建档使用。新 Skynet 进程和 MySQL 容器重启恢复均通过。详见 [player-profile-storage.md](player-profile-storage.md) 和产品 `Docs/ServerProfilePersistence.md`；下文关于只持久化金币的描述保留为最初切片的历史范围。

客户端共享框架和 Skynet 服务端按 `scripts/game/protos/networkpacket.proto` 的字段定义共用传输外壳；产品侧 `Account.cs` 由服务端 `account.proto` 生成，csharp_namespace 不改变 wire 格式。旧 player.proto 保留用于拒绝旧演示操作及兼容只读金币查询。本文约定业务命名与连接控制语义。

## 消息约定

- 每个 WebSocket binary frame 的负载是一整个 protobuf `NetworkPacket`。
- `protocol_name` 使用业务请求 protobuf 的**短 descriptor 名**，即 `AuthenticateRequest`、`PlayerProfileRequest`。不要用 handler 昵称或带 package 的全名。
- 请求和响应保留原 `session_id` 与 `protocol_name`；有效请求会话号非零。`session_id=0` 留给控制/推送消息，永不匹配等待中的业务请求。
- 成功响应的 `payload` 是响应 protobuf 字节；失败响应保留请求会话与协议名，填充 `error_code` / `error_msg`。当前开发端错误码统一为 1，后续再建立可版本化的业务错误码表。
- 心跳每 10 秒发送一个 `NetworkPacket(protocol_name="Heartbeat", session_id=0)`，时间戳为 Unix 秒，payload 为空；服务端原样以成功包回应。心跳不经过业务路由或玩家服务。

## 当前开发路由

| 请求 descriptor | 玩家服务响应 descriptor | 服务 |
| --- | --- | --- |
| `AuthenticateRequest` | `AuthenticateResponse` | playermgr，经本地开发身份提供器认证后返回服务端映射 ID |
| `PlayerProfileRequest` | `PlayerProfileResponse` | 当前连接已绑定的 player，版本化只读快照 |
| `PlayerInfoRequest` | `PlayerInfoResponse` | 已认证 player，兼容只读金币查询 |
| `ExplorationStateRequest` | `ExplorationStateResponse` | 已认证player，探索快照；无行时revision0 |
| `RecordExplorationPointRequest` | `RecordExplorationPointResponse` | 已认证player，非经济点记录；新增/已记录/版本冲突 |
| `LoginRequest` / `AddCoinsRequest` | 关联错误包 | 始终拒绝，不再支持固定 player_id 与客户端经济增量 |
| `TestRequest` | 无公开客户端入口 | 例子服务保留，agent 仅允许认证后玩家协议 |

`scripts/tools/test_client.lua` 默认验证关联错误、认证前查询拒绝、旧登录拒绝、错误令牌、正确认证及档案、加金币拒绝、失败认证清除旧绑定、第二账号映射、心跳与重连后重新认证。令牌仅从容器 `/run/gsf-development-accounts.json` 读取，不放在命令行或日志中。`bash scripts/tools/run_test_client.sh 127.0.0.1 8888 verify <预期金币>` 可在重启 Skynet 后确认只读金币恢复；包装脚本有 12 秒进程上限，失败非零退出。

Docker Compose 将 WebSocket 端口绑定到宿主 `127.0.0.1:8888`，允许本机 Unity Editor 后续直接连接，同时避免将开发服务器暴露到局域网。

2026-09-30 联调证据：容器内 Lua 客户端完成关联错误、登录、玩家信息、加金币、心跳、重连；Skynet 进程重启后只读查询也确认 Redis 中金币值恢复。Unity 2022.3.62f3c1 的 batchmode Editor 冒烟随后使用 `ws://127.0.0.1:8888` 完成只读登录和玩家信息请求（player `10001`，coins `200`）。这次还暴露并修复了框架端连接等待和 NativeWebSocket 桌面消息队列没有泵送的问题。

上段 2026-09-30 固定 ID/加金币证据是此前协议基线，不是当前允许的操作。当前 Unity Editor 冒烟已替换为预置测试账号认证与版本化档案读取；产品另有显式开启的只读 Play 入口。客户端必须拿到服务端映射身份与合法档案后才初始化玩法，失败不进入本地访客流程。

## 开发账号与档案范围

无 development_accounts_path 配置时默认拒绝全部认证。加载的外部 JSON 由服务端校验账号名、随机令牌、纯数字角色 ID 及重复配置；每次认证成功仅返回身份副本，不回传令牌。认证错误公开回复为通用 request rejected，保留 session/protocol 关联，不返回栈、凭证或内部路径。重新认证先解除旧连接绑定，失败后旧档案也不可读。玩家服务创建用 queue 串行化，避免同时登录同一身份创建重复实体。

PlayerProfileResponse 的 schema_version=1/revision=1 是当前只读种子版本：等级3、经验25、昵称 Test Traveler、空背包、零登录统计；金币来自历史 Redis。没有完整档案持久化/更新、生产认证、过期令牌/限流、多设备会话限制或服务端经济结算。明文 ws 只允许本机无个人信息的合成测试身份，真实凭证必须使用新的 TLS 认证链路。

生成/复制仓库外账号、启动配置、Editor 开关、账号切换和完整验证记录见 `D:/Test/AnimeOpenWorld/Docs/ReadOnlyOnlineSlice.md`。本次认证提供器 10 项检查、Lua 实连接切片、重启后金币200只读校验和 Unity 产品入口均通过；旧本地 player_data 未上传、合并或删除。

C# 消息生成（产品根目录）：

```powershell
protoc --proto_path=D:\Test\game_server_framework\scripts\game\protos --csharp_out=Assets/Scripts/Game/Network D:\Test\game_server_framework\scripts\game\protos\account.proto
```
