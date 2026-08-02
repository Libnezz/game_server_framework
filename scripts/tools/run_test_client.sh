#!/usr/bin/env bash
# 测试客户端包装脚本（开发期工具）
# 说明：skynet 的 client.so 演示库会在 require 时启动一个读 stdin 的后台线程，
# stdin 一旦 EOF 就会 exit(1) 杀掉进程，所以用 sleep 管道让 stdin 保持打开。
cd "$(dirname "$0")/../.."
sleep 3 | ./skynet/3rd/lua/lua scripts/tools/test_client.lua "$@"
