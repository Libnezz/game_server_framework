-- 玩家会话服务（agent）：一个 WebSocket 连接一个实例
-- 流程：接收 NetworkPacket → 按 protocol_name 经 router 分发到业务模块 → 回包
local skynet = require "skynet"
local websocket = require "http.websocket"
local proto = require "proto"
local rpc = require "rpc"
local log = require "log"

local WATCHDOG
local ws_id
local player_handle -- 登录后绑定玩家实体

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
        local request_session_id = 0
        local request_protocol_name = ""
        local ok, err = pcall(function()
            local packet = proto.decode(NETWORK_PACKET, data)
            request_session_id = packet.session_id or 0
            request_protocol_name = packet.protocol_name or ""
            log.info("agent recv: protocol=%s session=%s",
                tostring(packet.protocol_name), tostring(packet.session_id))

            -- 心跳同样是 NetworkPacket,session_id=0;不进入业务路由和玩家服务。
            if packet.session_id == 0 and packet.protocol_name == "Heartbeat" then
                websocket.write(id, make_packet(0, "Heartbeat"), "binary")
                return
            end

            assert(request_session_id > 0, "business request session must be positive")
            if request_protocol_name == "LoginRequest" or request_protocol_name == "AddCoinsRequest" then
                error("legacy development operation disabled")
            end

            local resp_bytes
            if packet.protocol_name == "AuthenticateRequest" then
                -- Clear old binding before every authentication attempt. A failed switch cannot reuse it.
                player_handle = nil
                local handle
                resp_bytes, handle = rpc.dispatch(packet.protocol_name, packet.payload)
                assert(handle, "authentication failed")
                player_handle = handle
            elseif player_handle and (request_protocol_name == "PlayerProfileRequest" or request_protocol_name == "PlayerInfoRequest") then
                -- 已登录：业务协议直接转发给玩家实体
                resp_bytes = skynet.call(player_handle, "lua", packet.protocol_name, packet.payload)
            else
                error("authenticated read-only protocol required")
            end
            websocket.write(id, make_packet(packet.session_id, packet.protocol_name, resp_bytes), "binary")
        end)
        if not ok then
            log.warn("agent request rejected: protocol=%s session=%s", request_protocol_name, request_session_id)
            -- 错误也要带回请求的会话号,让客户端立刻结束对应等待。
            -- No internal stack traces, request payloads or credentials in public errors.
            websocket.write(id, make_packet(request_session_id, request_protocol_name, nil, "request rejected"), "binary")
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
