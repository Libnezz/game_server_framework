# WebSocket NetworkPacket 约定

客户端共享框架和 Skynet 服务端按 `scripts/game/protos/networkpacket.proto` 的字段定义共用传输外壳；产品侧玩家消息由服务端 `player.proto` 生成 C# 副本，额外的 C# namespace 选项不改变 wire 格式。本文约定业务命名与连接控制语义。

## 消息约定

- 每个 WebSocket binary frame 的负载是一整个 protobuf `NetworkPacket`。
- `protocol_name` 使用业务请求 protobuf 的**短 descriptor 名**，即 `LoginRequest`、`PlayerInfoRequest`、`AddCoinsRequest`。不要用 handler 昵称或带 package 的全名。
- 请求和响应保留原 `session_id` 与 `protocol_name`；有效请求会话号非零。`session_id=0` 留给控制/推送消息，永不匹配等待中的业务请求。
- 成功响应的 `payload` 是响应 protobuf 字节；失败响应保留请求会话与协议名，填充 `error_code` / `error_msg`。当前开发端错误码统一为 1，后续再建立可版本化的业务错误码表。
- 心跳每 10 秒发送一个 `NetworkPacket(protocol_name="Heartbeat", session_id=0)`，时间戳为 Unix 秒，payload 为空；服务端原样以成功包回应。心跳不经过业务路由或玩家服务。

## 当前开发路由

| 请求 descriptor | 玩家服务响应 descriptor | 服务 |
| --- | --- | --- |
| `LoginRequest` | `LoginResponse` | playermgr（认证尚未实现；开发测试可传固定 player_id） |
| `PlayerInfoRequest` | `PlayerInfoResponse` | player |
| `AddCoinsRequest` | `AddCoinsResponse` | player |
| `TestRequest` | `TestResponse` | testmodule（无登录 echo 例子） |

`scripts/tools/test_client.lua` 默认验证未知路由的关联错误、登录、查询、加金币、心跳与断线重连；连接重建只验证 playermgr 复用内存态。另有只读验证模式：`bash scripts/tools/run_test_client.sh 127.0.0.1 8888 verify <预期金币>`，可在完整重启 Skynet 后确认 player 从 Redis 恢复数据。

Docker Compose 将 WebSocket 端口绑定到宿主 `127.0.0.1:8888`，允许本机 Unity Editor 后续直接连接，同时避免将开发服务器暴露到局域网。

2026-09-30 联调证据：容器内 Lua 客户端完成关联错误、登录、玩家信息、加金币、心跳、重连；Skynet 进程重启后只读查询也确认 Redis 中金币值恢复。Unity 2022.3.62f3c1 的 batchmode Editor 冒烟随后使用 `ws://127.0.0.1:8888` 完成只读登录和玩家信息请求（player `10001`，coins `200`）。这次还暴露并修复了框架端连接等待和 NativeWebSocket 桌面消息队列没有泵送的问题。

Unity 工程现有 `Assets/Editor/NetworkSmokeTest.cs` 是开发验证入口，不属于产品 UI；登录流程、钱包界面和本地存档与服务器数据的迁移仍未接线。示例 `LoginRequest` 仅凭固定玩家编号建立开发会话，不提供账号鉴权，也不应作为正式登录方案。
