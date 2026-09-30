-- 玩家管理器：管理玩家实体生命周期（登录创建/复用、登出销毁、在线查询）
-- 登录协议在此处理：返回响应字节 + 玩家实体句柄（agent 绑定用）
local skynet = require "skynet"
local proto = require "proto"
local rpc = require "rpc"
local log = require "log"
local accounts = require("development_accounts").load(skynet.getenv("development_accounts_path"))
local queue = require "skynet.queue"
local login_lock = queue()

local P = "Game.Framework.Network."
local players = {} -- player_id -> player 服务句柄

local CMD = {}

-- 登录：玩家在线则复用，否则创建 player 实体
function CMD.login(identity)
    local player_id = identity.player_id
    local p = players[player_id]
    if not p then
        p = skynet.newservice("player", player_id)
        players[player_id] = p
        log.info("playermgr: player %s online", player_id)
    else
        log.info("playermgr: player %s reused", player_id)
    end
    local resp = proto.encode(P .. "AuthenticateResponse", identity)
    return resp, p -- 第二个返回值让 agent 绑定该玩家
end

function CMD.logout(player_id)
    local p = players[player_id]
    if p then
        players[player_id] = nil
        skynet.send(p, "lua", "logout")
        log.info("playermgr: player %s logged out", player_id)
    end
    return true
end

function CMD.online()
    local n = 0
    for _ in pairs(players) do
        n = n + 1
    end
    return n
end

skynet.start(function()
    rpc.register("AuthenticateRequest")
    log.info("playermgr started")

    skynet.dispatch("lua", function(session, source, cmd, ...)
        if cmd == "AuthenticateRequest" then
            local req = proto.decode(P .. "AuthenticateRequest", ...)
            local identity = accounts.authenticate(req.account_id, req.development_token)
            assert(identity, "authentication failed")
            skynet.ret(skynet.pack(login_lock(CMD.login, identity)))
        else
            local f = assert(CMD[cmd], cmd)
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)
