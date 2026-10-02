-- MySQL 服务：持有 MySQL 连接，提供 query/execute/quote 接口
-- 连接由 socketchannel 自动重连；业务侧建议用 framework/utils/db.lua 访问
local skynet = require "skynet"
require "skynet.manager"
local mysql = require "skynet.db.mysql"
local log = require "log"

local db

local function connect()
    db = mysql.connect({
        host = skynet.getenv("mysql_host") or "127.0.0.1",
        port = tonumber(skynet.getenv("mysql_port") or "3306"),
        database = skynet.getenv("mysql_database") or "game",
        user = skynet.getenv("mysql_user") or "root",
        password = skynet.getenv("mysql_password") or "",
        charset = "utf8mb4",
    })
end

local CMD = {}

-- SELECT 查询，返回行数组（每行为字段名 -> 值的表）
function CMD.query(sql)
    local res = db:query(sql)
    if not res or res.badresult then
        error("mysql query failed (errno=" .. tostring(res and res.errno) .. ")")
    end
    return res
end

-- 写操作（INSERT/UPDATE/DELETE/DDL），返回 affected_rows/insert_id 等
function CMD.execute(sql)
    local res = db:query(sql)
    if not res or res.badresult then
        error("mysql execute failed (errno=" .. tostring(res and res.errno) .. ")")
    end
    return res
end

function CMD.insert_if_absent(sql)
    local res = db:query(sql)
    if res and res.badresult and res.errno == 1062 then return { affected_rows = 0 } end
    if not res or res.badresult then error("mysql insert failed (errno=" .. tostring(res and res.errno) .. ")") end
    return res
end

-- 字符串转义（拼接 SQL 时使用）
function CMD.quote(str)
    return mysql.quote_sql_str(str)
end

skynet.start(function()
    local ok, err = pcall(connect)
    if not ok then
        skynet.error(string.format("mysqlservice connect failed: %s", tostring(err)))
        skynet.abort()
    end
    log.info("mysqlservice connected: %s:%s db=%s",
        skynet.getenv("mysql_host") or "127.0.0.1",
        skynet.getenv("mysql_port") or "3306",
        skynet.getenv("mysql_database") or "game")

    skynet.name(".mysqlservice", skynet.self())

    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd)
        skynet.ret(skynet.pack(f(...)))
    end)
end)
