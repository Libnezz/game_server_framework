-- 玩家会话服务（agent）：一个连接一个实例，承载该玩家的网络会话
-- 第一阶段：回显收到的数据，验证 gate → watchdog → agent → 客户端 全链路
-- 后续：解析 NetworkPacket（protobuf），按 protocol_name 分发到业务模块
local skynet = require "skynet"
local socket = require "skynet.socket"
local log = require "log"

local WATCHDOG
local gate
local client_fd

local CMD = {}

function CMD.start(conf)
    gate = conf.gate
    client_fd = conf.client
    WATCHDOG = conf.watchdog
    -- 让 gate 把该连接的后续数据包直接转发给本服务
    skynet.call(gate, "lua", "forward", client_fd)
    log.info("agent started: fd=%d addr=%s", client_fd, skynet.address(skynet.self()))
end

function CMD.disconnect()
    log.info("agent disconnected: fd=%d", client_fd)
    skynet.exit()
end

-- 客户端数据包（gate 转发，wire 协议：2 字节大端长度 + 负载）
skynet.register_protocol {
    name = "client",
    id = skynet.PTYPE_CLIENT,
    unpack = skynet.tostring,
    dispatch = function(fd, _, msg)
        assert(fd == client_fd)
        skynet.ignoreret() -- 客户端消息的 session 是 fd，不需要回响应
        log.info("agent recv: %s", tostring(msg))
        -- 回显（第一阶段验证用；后续改为解析协议并路由业务）
        local package = string.pack(">s2", msg)
        socket.write(client_fd, package)
    end,
}

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd)
        skynet.ret(skynet.pack(f(...)))
    end)
end)
