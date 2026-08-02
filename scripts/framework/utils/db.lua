-- 数据库访问辅助：业务服务通过它调用数据库服务
local skynet = require "skynet"

local M = {}

-- Redis 通用命令（如 db.redis("SET", "key", "value")）
function M.redis(command, ...)
    return skynet.call(".redisservice", "lua", "cmd", command, ...)
end

-- MySQL 查询（SELECT，返回行数组）
function M.mysql_query(sql)
    return skynet.call(".mysqlservice", "lua", "query", sql)
end

-- MySQL 写操作（INSERT/UPDATE/DELETE/DDL）
function M.mysql_execute(sql)
    return skynet.call(".mysqlservice", "lua", "execute", sql)
end

return M
