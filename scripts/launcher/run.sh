#!/usr/bin/env bash
# 启动服务端：在容器内或本机 Linux 上从项目根目录执行
set -e
cd "$(dirname "$0")/../.."
exec ./skynet/skynet etc/config "$@"
