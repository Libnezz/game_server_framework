-- 玩家实体服务：每玩家一个，持有玩家数据与业务模块（managers）
-- 创建：playermgr 通过 newservice("player", player_id) 拉起
local skynet = require "skynet"
local proto = require "proto"
local db = require "db"
local log = require "log"

local P = "Game.Framework.Network."
local player_id = assert(...)
local profile_module = require "player_profile_repository"
local store = require("mysql_document_store").new({
    query = db.mysql_query, execute = db.mysql_execute, quote = db.mysql_quote,
}, "player_profiles")
local profiles = profile_module.new(store, function(id)
    -- Only for first server-side creation; never read or import the client player_data archive.
    local legacy_coins = db.redis("GET", "player:" .. id .. ":coins")
    return profile_module.seed(id, tonumber(legacy_coins or "0"))
end)
local X = "AnimeOpenWorld.Exploration.V1."
local exploration = require("player_exploration_repository").new(require("mysql_document_store").new({
    query = db.mysql_query, execute = db.mysql_execute, quote = db.mysql_quote,
    insert_if_absent = db.mysql_insert_if_absent,
}, "player_exploration"))

local HANDLERS = {
    ExplorationStateRequest = function(payload)
        local req = proto.decode(X .. "ExplorationStateRequest", payload)
        return proto.encode(X .. "ExplorationStateResponse", exploration.read(player_id, req.goal_id, req.definition_version))
    end,
    RecordExplorationPointRequest = function(payload)
        local req = proto.decode(X .. "RecordExplorationPointRequest", payload)
        return proto.encode(X .. "RecordExplorationPointResponse", exploration.record(player_id,
            req.goal_id, req.definition_version, req.point_id, req.expected_revision or 0))
    end,
    PlayerProfileRequest = function()
        return proto.encode(P .. "PlayerProfileResponse", profiles.read(player_id))
    end,
    -- 玩家业务模块入口（后续按 managers 组织）
    PlayerInfoRequest = function()
        return proto.encode(P .. "PlayerInfoResponse", { player_id = player_id, coins = profiles.read(player_id).coins })
    end,
    AddCoinsRequest = function(payload)
        error("client-authored economy changes are disabled")
    end,
    logout = function()
        log.info("player %s logout; read-only profile already persisted", player_id)
        skynet.exit()
    end,
}

skynet.start(function()
    local profile = profiles.load_or_create(player_id)
    log.info("player %s profile loaded, schema=%d revision=%d", player_id, profile.schema_version, profile.revision)

    skynet.dispatch("lua", function(session, source, protocol_name, payload)
        local f = HANDLERS[protocol_name]
        if not f then
            error(string.format("player: unknown protocol %q", tostring(protocol_name)))
        end
        skynet.ret(skynet.pack(f(payload)))
    end)
end)
