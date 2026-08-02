# Docker 开发环境

项目代码通过 bind mount 挂载进容器，在 Windows 上改代码即时生效，编译和运行都在 Linux 容器内完成。

## 启动开发容器

```powershell
docker compose up -d --build
```

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
