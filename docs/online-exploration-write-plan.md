# 首次探索进度写入：实施边界

2026-10-02 后续：服务端实现和验证已完成，实际接口与证据见 [exploration-progress.md](exploration-progress.md)。下文保留实施前草案；运行协议以 `scripts/game/protos/exploration.proto` 为准，docs/contracts文件不参与加载。

2026-10-02，状态：需求/协议草案，尚未实现或开放。产品完整需求、完成校验、奖励准入与验收矩阵统一维护在 [OnlineExplorationWriteRequirements.md](https://github.com/Libnezz/AnimeOpenWorld/blob/main/Docs/OnlineExplorationWriteRequirements.md)，本仓库保留服务端落点和可编译契约。

## 先做什么

首切是已认证角色的非经济探索进度：目标1、定义版本1、成员3001/3002，可逆序，跨登录保留。同点重复不升版本；未建行查询为空revision0，首次写入revision1。协议草案见 [contracts/exploration-write-v1.proto](contracts/exploration-write-v1.proto)。该文件在docs目录，不加入运行时proto清单，也未加入agent白名单。

服务端只有身份/档案，没有玩家位置、调查计时、受击或场景权威模拟。首次上报依赖开发客户端声明，服务端只校验身份、配置/成员、幂等与存储条件；不能声称已经验证空间行为，更不能据此发金币、经验、物品或可兑换凭证。

## 代码和存储落点

- `scripts/framework/utils/mysql_document_store.lua`：按真实需求补通用条件更新/首次创建结果语义，识别数据库失败和CAS竞争；不加入目标或奖励字段。
- 新产品业务repository：校验探索文档、可信目标定义、点集合、版本、只增不回退和自然幂等；业务键为player/goal/point。
- 新MySQL `player_exploration` 文档：record_id为服务端player ID，schema/revision/body结构复用文档形状。探索revision独立，`player_profiles`及旧Redis金币键均不改。
- `scripts/game/modules/player.lua`：读取/记录探索的业务处理；`agent.lua`仅在接口和测试完成后窄化开放两个已认证协议，不开放通用任意写入。
- 服务端独立可信定义与客户端发布内容校对，固定definition_version=1；内容版本改变不自动重置目标或一次性权益。

更新需先校验当前文档：已存在该点时直接回重复确认；不同revision回冲突；首次插入或条件更新成功后回读。CAS败者回读，不能无条件覆盖胜出者的点。新进程和多连接竞争仍由数据库约束兜底。

## 暂缓的经济接口

当前没有奖励数量、领奖协议或钱包写入。未来必须具备可信完成证据与同连接隔离事务，再把任务状态、持久化一次性回执及钱包/背包一起提交。现有mysqlservice多个独立RPC不能当作该事务能力；仅player协程串行或内存去重不能解决跨进程/崩溃重复结算。

## 实施和验证顺序

1. 纯Lua仓库及数据库适配测试：非法字段/成员、坏行不重建、逆序、重复、revision/CAS竞争。
2. 真实MySQL测试：独立身份的首次创建、多写者、DB失败、新进程与数据库重启恢复；只清理明确属于本次测试的行。
3. 启用两个窄协议并跑Lua实连接：未认证拒绝、账号隔离、两点写入、重复提交、丢回复后回读，确认人物档案无改动。
4. Unity读取快照后才允许调查，提交前取消不发写入，提交后取消结果未知并回读；generation与revision守卫防止旧响应污染新状态。

完整验收条件以产品需求文档为准。本轮只验证proto草案语法和文档与现有源码对应关系，不声称上述实现或运行验证已完成。skynet子模块既存工作区改动继续保留。
