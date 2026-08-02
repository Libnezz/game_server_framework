# 数据库备份（Windows 开发期工具）：导出 MySQL 与 Redis 数据到 backups/ 目录
# 用法：在 PowerShell 中执行  powershell -File scripts/tools/backup_db.ps1
$ErrorActionPreference = 'Stop'

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$backupDir = Join-Path $root 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'

# MySQL：先导出到容器内临时文件，再 docker cp 出来（避免 PowerShell 管道编码问题）
docker exec gsf-mysql sh -c "mysqldump -uroot -proot --databases game > /tmp/dump.sql"
docker cp gsf-mysql:/tmp/dump.sql (Join-Path $backupDir "mysql_${ts}.sql")

# Redis：SAVE 生成 RDB 快照后拷出
docker exec gsf-redis redis-cli SAVE | Out-Null
docker cp gsf-redis:/data/dump.rdb (Join-Path $backupDir "redis_${ts}.rdb")

Write-Host "backup done: backups\mysql_${ts}.sql , backups\redis_${ts}.rdb"
