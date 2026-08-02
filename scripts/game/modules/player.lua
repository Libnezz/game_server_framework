-- 玩家实体服务：每玩家一个，持有玩家数据与业务模块（managers）
-- 创建：playermgr 通过 newservice("player", player_id) 拉起
local skynet = require "skynet"
local proto = require "proto"
local db = require "db"
local log = require "log"

local P = "Game.Framework.Network."
local player_id = assert(...)
local coins = 0

local function redis_key(k)
    return "player:" .. player_id .. ":" .. k
end

local HANDLERS = {
    -- 玩家业务模块入口（后续按 managers 组织）
    GetPlayerInfo = function()
        return proto.encode(P .. "PlayerInfoResponse", { player_id = player_id, coins = coins })
    end,
    AddCoins = function(payload)
        local req = proto.decode(P .. "AddCoinsRequest", payload)
        coins = coins + (req.amount or 0)
        db.redis("SET", redis_key("coins"), coins) -- 写穿 Redis，演示持久化
        log.info("player %s coins -> %d", player_id, coins)
        return proto.encode(P .. "AddCoinsResponse", { coins = coins })
    end,
    logout = function()
        log.info("player %s logout, save coins=%d", player_id, coins)
        db.redis("SET", redis_key("coins"), coins)
        skynet.exit()
    end,
}

skynet.start(function()
    -- 加载玩家数据（演示：金币存 Redis）
    local v = db.redis("GET", redis_key("coins"))
    coins = tonumber(v or "0")
    log.info("player %s loaded, coins=%d", player_id, coins)

    skynet.dispatch("lua", function(session, source, protocol_name, payload)
        local f = HANDLERS[protocol_name]
        if not f then
            error(string.format("player: unknown protocol %q", tostring(protocol_name)))
        end
        skynet.ret(skynet.pack(f(payload)))
    end)
end)
