# 完整玩家档案存储

2026-09-30：开发账号只读档案已使用 MySQL 持久化。认证及客户端协议见 [network-protocol.md](network-protocol.md)。

## 数据路径

认证提供器返回服务端指定的身份，playermgr 创建/复用 player。player 通过业务 `player_profile_repository` 读取通用 `mysql_document_store`，首次创建完整 JSON；后续每次档案查询从数据库读取并校验。MySQL `player_profiles` 的身份主键、schema_version、revision 和 JSON body 在单条 InnoDB INSERT 中落盘。

通用文档仓库只认识键/版本/JSON和注入的数据库接口，不认识金币/等级；业务仓库负责具体字段、范围、UTF8、背包和身份/版本一致性。创建冲突不覆盖记录，而是读取已存在的胜出快照。已有坏数据、未知schema、列与JSON版本不符、读写错误都拒绝，不生成新种子，不回退Redis/客户端档案。

首次建档仍使用阶段种子，金币仅在首次创建读取已有服务端Redis开发键。已建档的读请求和登出不再读写旧金币键，旧键保留。当前schema=1、种子revision=1；尚无更新/CAS、登录统计写入或经济结算接口。此版本号仅用于完整性校验，不代表已实现业务幂等。

## 迁移

在仓库根目录执行（现有和新数据库均显式应用）：

```powershell
docker --context desktop-linux cp docker/mysql/migrations/001_player_profiles.sql gsf-mysql:/tmp/001_player_profiles.sql
docker --context desktop-linux exec gsf-mysql sh -c 'MYSQL_PWD=game mysql -ugame -D game < /tmp/001_player_profiles.sql'
```

这是增量 CREATE TABLE，不删除或替换数据。game是现有开发数据库账号，玩家测试令牌仍在仓库外。已有volume不会重新运行init.sql；迁移完成后重启Skynet。缺表直接使建档失败，不能绕过存储进入玩法。

## 验证

```powershell
docker --context desktop-linux exec gsf-dev ./skynet/3rd/lua/lua scripts/tools/test_player_profiles.lua
docker --context desktop-linux exec gsf-dev bash scripts/tools/run_profile_storage_test.sh
docker --context desktop-linux exec gsf-dev bash scripts/tools/run_test_client.sh
```

纯Lua仓库24项检查通过。真实MySQL测试使用独立的9900...数字测试身份和两个Skynet进程，验证完整非默认档案、UTF8与引号、背包、重复创建不覆盖、数据库错误识别、坏数据不重建、protobuf编码恢复。测试不启动监听器、不读取测试账号凭证；正常完成清理自己的行。异常中断留下的测试行应先核对来源，不能按前缀删除未知数据。

本机完整档案在新的Skynet进程中恢复通过；停止Skynet、重启MySQL并保留volume、待数据库可查询后启动Skynet，Lua只读验证与Unity2022 Editor冒烟仍返回玩家10001金币200；第二账号10002金币0。当前业务只读限制、关联错误、失败重认证清理与旧客户端档案保留均继续生效。

MySQL驱动返回badresult表的SQL错误已转为服务调用失败，不作为空结果；字符串引号使用mysql模块静态工具。未验证数据库备份恢复/长期故障恢复、生产认证、多设备会话限制、经济结算或真机。下一步先定义服务端写操作的幂等/版本/失败补偿，再开放一个经过校验的玩法事件。
