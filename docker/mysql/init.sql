-- MySQL 初始化脚本（首次初始化数据目录时执行）
-- skynet 的 mysql 客户端仅支持 mysql_native_password，故应用账号使用该插件
CREATE USER IF NOT EXISTS 'game'@'%' IDENTIFIED WITH mysql_native_password BY 'game';
GRANT ALL PRIVILEGES ON game.* TO 'game'@'%';
FLUSH PRIVILEGES;
