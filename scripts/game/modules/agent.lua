-- 玩家会话服务（agent）：一个 WebSocket 连接一个实例
-- 流程：接收 NetworkPacket → 按 protocol_name 经 router 分发到业务模块 → 回包
local skynet = require "skynet"
local websocket = require "http.websocket"
local proto = require "proto"
local rpc = require "rpc"
local log = require "log"

local WATCHDOG
local ws_id

local NETWORK_PACKET = "Game.Framework.Network.NetworkPacket"

local function make_packet(session_id, protocol_name, payload, err)
    return proto.encode(NETWORK_PACKET, {
        session_id = session_id or 0,
        protocol_name = protocol_name or "",
        payload = payload or "",
        timestamp = os.time(),
        error_code = err and 1 or 0,
        error_msg = err or "",
    })
end

local handle = {
    message = function(id, data)
        local ok, err = pcall(function()
            local packet = proto.decode(NETWORK_PACKET, data)
            log.info("agent recv: protocol=%s session=%s",
                tostring(packet.protocol_name), tostring(packet.session_id))
            local resp_bytes = rpc.dispatch(packet.protocol_name, packet.payload)
            websocket.write(id, make_packet(packet.session_id, packet.protocol_name, resp_bytes))
        end)
        if not ok then
            log.error("agent dispatch failed: %s", tostring(err))
            websocket.write(id, make_packet(0, "", nil, tostring(err)))
        end
    end,
    close = function(id)
        log.info("ws closed: fd=%d", id)
        skynet.exit()
    end,
    error = function(id, err)
        log.info("ws error: fd=%d (%s)", id, tostring(err))
    end,
}

local CMD = {}

function CMD.start(conf)
    WATCHDOG = conf.watchdog
    ws_id = conf.fd
    log.info("agent started: fd=%d addr=%s", ws_id, tostring(conf.addr))
    skynet.fork(function()
        websocket.accept(ws_id, handle, "ws", conf.addr)
        skynet.exit()
    end)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd)
        skynet.ret(skynet.pack(f(...)))
    end)
end)
