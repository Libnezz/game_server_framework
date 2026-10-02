# 非经济探索进度写入

2026-10-02：服务端已实现并验证。产品完整需求见 [在线探索写入需求](https://github.com/Libnezz/AnimeOpenWorld/blob/main/Docs/OnlineExplorationWriteRequirements.md)。本接口记录开发客户端的调查声明，不证明空间行为，不发金币、经验、物品或可兑换奖励。

## 行为与边界

已认证agent只增加放行 `ExplorationStateRequest` 与 `RecordExplorationPointRequest`，消息源见 `scripts/game/protos/exploration.proto`；玩家身份来自agent绑定的player，不来自请求字段。目标1、定义1、成员3001/3002由业务 `exploration_definitions` 独立持有。

查询没有行时返回revision0/AVAILABLE，不创建行。首次上报写revision1，另一点以当前revision做CAS追加到revision2/COMPLETED。重复点先识别并返回ALREADY_RECORDED，不升版本；旧revision的新点返回REVISION_CONFLICT和当前快照。成功写入后回读校验，再返回RECORDED。坏行、配置不匹配、未知成员或数据库失败拒绝，不重建0/2。

存储为独立 `player_exploration` JSON文档，schema_version=1；人物档案及旧Redis金币均不改变。增量迁移 `docker/mysql/migrations/002_player_exploration.sql` 必须对已有volume显式应用，不能依赖init.sql，也不删除旧数据。

通用文档仓库新增try_create与compare_and_swap，业务仓库负责具体字段与点集合。Skynet驱动开启FOUND_ROWS，无变化upsert也报告1；try_create使用普通INSERT和MySQL服务的显式重复键1062→未创建结果，其他SQL错误仍失败。CAS仅在ID/schema/revision条件匹配时更新，无条件覆盖禁止。原create_if_absent契约保留给只读人物档案。

## 本轮服务端验证

- 探索纯Lua **23项**：正序/逆序、重复/冲突、角色隔离、重开仓库、创建/CAS竞争、非法输入与坏行不重建、数据库失败、条件SQL与影响行数。
- 既有档案纯Lua **24项**与真实MySQL两进程恢复回归通过。
- 真实MySQL探索测试：两独立写者竞争第一行、一成功一冲突，失败者回读再提交，最终两点无丢失；重复不升版本，旧CAS不覆盖、坏行拒绝、缺表失败；新Skynet进程恢复1/2后完成2/2并只清理自己的9901...测试行。
- Lua实连接：未认证读/写拒绝、非法点/旧定义拒绝、两点写入与重复、两账号隔离、人物档案protobuf前后相同；已拒绝的旧Login/AddCoins保持拒绝。
- 停止开发Skynet、重启MySQL（保留volume）、新Skynet进程启动后，实连接再次读取并重复上报仍为revision2/2点，人物档案不变。

复现入口：`scripts/tools/test_player_exploration.lua`、`run_exploration_storage_test.sh`、`run_test_client.sh 127.0.0.1 8888 exploration`。最后一个入口会推进第一个预置开发账号的非经济进度并保留它；不改人物档案，不清除该账号数据。

后续产品阶段现已完成：在线确认/恢复提交 `301eea3`，真实Skynet/MySQL PlayMode验证提交前取消、未确认不计数、重登1/2、取消客户端等待后查询2/2、连接关闭清理/重登2/2、两账号隔离及档案不变；地标表现加入不同轮廓/颜色、世界名称牌、进度环与确认脉冲。产品最终EditMode192/192，整套宿主PlayMode36通过/0失败/3既有跳过，布局调整后产品5/5复验通过。见 [在线探索接入](https://github.com/Libnezz/AnimeOpenWorld/blob/main/Docs/OnlineExplorationProgress.md) 与 [地标表现](https://github.com/Libnezz/AnimeOpenWorld/blob/main/Docs/ExplorationPresentation.md)。临时账号/数据库行独立于既有开发身份，验证后恢复原凭证与Skynet配置。

客户端取消等待验证不等同物理丢包注入。没有经济事务、权威位置/调查模拟、新IL2CPP/热更包、移动端或长期压力验证；skynet既存工作区改动未处理。
