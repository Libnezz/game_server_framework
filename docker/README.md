# Docker 开发环境

项目代码通过 bind mount 挂载进容器，在 Windows 上改代码即时生效，编译和运行都在 Linux 容器内完成。

## 启动开发容器

```powershell
docker compose up -d --build
```

`docker compose up` 会同时启动依赖的 MySQL（`gsf-mysql`，root/root，应用账号 game/game，库 game）与 Redis（`gsf-redis`）；首次启动 MySQL 会自动执行 [`docker/mysql/init.sql`](docker/mysql/init.sql) 创建应用账号。

## 数据持久化

MySQL 与 Redis 的数据分别存放在命名卷 `mysql_data`、`redis_data` 中，容器重建不会丢失。

- 日常停止/启动：`docker compose down` + `docker compose up -d` —— 数据保留。
- **`docker compose down -v` 会删除命名卷，数据全部清空**，仅用于刻意重置（如重新执行 init.sql）。
- 备份：Windows 上运行 `powershell -File scripts/tools/backup_db.ps1`，Linux 上运行 `bash scripts/tools/backup_db.sh`，导出到 `backups/` 目录。
- 注意：`docker/mysql/init.sql` 只在数据目录为空（首次初始化）时执行；修改 init.sql 后需重置数据卷或手动执行 SQL。

## 进入容器

```powershell
docker compose exec dev bash
```

## 在容器内编译 skynet

```bash
cd /app/skynet && make linux
```

## 运行框架（使用我们自己的配置与代码）

```bash
cd /app && bash run.sh
```

看到 `framework booted` 与 `echo service responded: framework alive` 即说明框架链路正常。

Windows 下可直接执行：

```powershell
docker compose exec dev bash -lc "cd /app && bash run.sh"
```

## 编译 protobuf 支持库（首次或升级 lua-protobuf 后）

```powershell
docker compose exec dev bash -lc "cd /app/third_party/lua-protobuf && gcc -O2 -shared -fPIC -I /app/skynet/3rd/lua pb.c -o /app/skynet/luaclib/pb.so"
```

产物 `pb.so` 位于 `skynet/luaclib/`（已被 git 忽略，不提交）。

## 停止

```powershell
docker compose down
```

## 说明

- `docker/Dockerfile` 是开发镜像（带 gcc/make/autoconf），部署镜像后续单独做。
- 端口映射暂未开启，等 gate/登录服务就绪后再在 `docker-compose.yml` 中放开。
