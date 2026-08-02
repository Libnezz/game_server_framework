-- Redis 服务：持有 Redis 连接，提供通用命令接口
-- 连接由 socketchannel 自动重连；业务侧建议用 framework/utils/db.lua 访问
local skynet = require "skynet"
require "skynet.manager"
local redis = require "skynet.db.redis"
local log = require "log"

local client

local function connect()
    client = redis.connect({
        host = skynet.getenv("redis_host") or "127.0.0.1",
        port = tonumber(skynet.getenv("redis_port") or "6379"),
        auth = skynet.getenv("redis_password"),
        db = tonumber(skynet.getenv("redis_db") or "0"),
    })
end

local CMD = {}

-- 通用命令：cmd 为 Redis 命令名（SET/GET/EXPIRE/HSET...），其余为参数
function CMD.cmd(command, ...)
    local f = client[command]
    return f(client, ...)
end

skynet.start(function()
    local ok, err = pcall(connect)
    if not ok then
        skynet.error(string.format("redisservice connect failed: %s", tostring(err)))
        skynet.abort()
    end
    log.info("redisservice connected: %s:%s db=%s",
        skynet.getenv("redis_host") or "127.0.0.1",
        skynet.getenv("redis_port") or "6379",
        skynet.getenv("redis_db") or "0")

    skynet.name(".redisservice", skynet.self())

    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd)
        skynet.ret(skynet.pack(f(...)))
    end)
end)
