#!/usr/bin/env bash
# 启动服务端：skynet 二进制 + 配置文件（在项目根目录执行）
set -e
cd "$(dirname "$0")"
exec ./skynet/skynet etc/config "$@"
