#!/usr/bin/env bash
# 数据库备份（开发期工具）：导出 MySQL 全库与 Redis RDB 到 backups/ 目录
set -e
cd "$(dirname "$0")/../.."
mkdir -p backups

ts=$(date +%Y%m%d_%H%M%S)

docker exec gsf-mysql mysqldump -uroot -proot --databases game > "backups/mysql_${ts}.sql" 2>/dev/null
docker exec gsf-redis redis-cli SAVE > /dev/null
docker cp gsf-redis:/data/dump.rdb "backups/redis_${ts}.rdb" > /dev/null 2>&1

echo "backup done: backups/mysql_${ts}.sql, backups/redis_${ts}.rdb"
