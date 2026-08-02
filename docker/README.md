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

## 冒烟测试（验证运行时可用）

```bash
cd /app/skynet && timeout 8 ./skynet examples/config
```

看到 `Start service: snlua bootstrap` 等启动日志即说明环境正常。

## 停止

```powershell
docker compose down
```

## 说明

- `docker/Dockerfile` 是开发镜像（带 gcc/make/autoconf），部署镜像后续单独做。
- 端口映射暂未开启，等 gate/登录服务就绪后再在 `docker-compose.yml` 中放开。
