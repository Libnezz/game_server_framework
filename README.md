# game_server_framework

通用Skynet服务端底座。AnimeOpenWorld的账号会话、玩家档案、探索定义/仓库、产品协议和迁移脚本已迁到独立的 [anime_open_world_server](https://github.com/Libnezz/anime_open_world_server)，本仓库不再启动产品业务。服务端仓库与目录沿用小写下划线命名，产品的框架子模块目录为 `framework`。

框架提供连接监听、协议装载、路由、配置装载、MySQL/Redis代理、带CAS的文档存储、开发凭证提供器与日志。宿主通过 `application_manifest` 指定自己的服务、完整proto路径及配置表清单；框架启动完成后启动宿主服务，最后开放监听。原生协议外壳仍为NetworkPacket，wire格式不变。

`examples/echo` 是独立框架宿主，仅允许TestRequest与心跳，没有玩家、探索或经济接口。`datas` 是此示例的配置输入。默认 `etc/config` 运行此示例；产品使用自己的配置，不覆盖框架入口。框架main不执行产品读写或启动自检建表。

## 本地开发

```powershell
docker --context desktop-linux compose up -d --build
docker --context desktop-linux exec gsf-dev bash -lc 'cd /app/skynet && make linux -j4'
docker --context desktop-linux exec gsf-dev bash -lc 'cd /app && gcc -O2 -shared -fPIC -I skynet/3rd/lua third_party/lua-protobuf/pb.c -o skynet/luaclib/pb.so'
docker --context desktop-linux exec gsf-dev bash -lc 'cd /app && bash run.sh'
```

看到 `application ready; ws listening` 即为就绪。框架与产品实例不能同时占用宿主8888；独立框架验证使用容器内8889。

```powershell
docker --context desktop-linux exec gsf-dev bash scripts/tools/run_test_client.sh 127.0.0.1 8889
docker --context desktop-linux exec gsf-dev sh -c 'cd /app && ./skynet/3rd/lua/lua scripts/tools/test_runtime_manifest.lua'
```

2026-10-02拆分验证：宿主清单8项、开发凭证提供器10项、独立Echo进程真实WebSocket/关联响应/心跳通过。产品回归见anime_open_world_server文档。此前docs中的账号/档案/探索记录为拆分前历史；后续产品维护以新工程为准。

框架不反向依赖产品。产品通过Git子模块固定框架提交；更新依赖后运行纯逻辑、真实数据库、实连接与Unity回归。现有开发数据库卷和skynet既存工作区改动保留，不随本次提取清理。
