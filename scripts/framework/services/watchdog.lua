-- 看门狗服务：WebSocket 连接监听（网络域 → 业务域的桥）
-- 职责：监听端口、接受连接，为每个连接创建 agent（agent 接管连接并运行 WS 循环）
-- 预留：将来引入 agent 管理器后，创建/复用 agent 的逻辑从这里迁出（登录、重连）
local skynet = require "skynet"
local socket = require "skynet.socket"
local log = require "log"

-- 配置（etc/config 中可覆盖）
local agent_service = skynet.getenv("agent_service") or "agent"
local ws_port = tonumber(skynet.getenv("ws_port") or "8888")

local CMD = {}

function CMD.start()
    local listen_fd = socket.listen("0.0.0.0", ws_port)
    socket.start(listen_fd, function(new_fd, addr)
        log.info("new ws connection: fd=%d from %s", new_fd, tostring(addr))
        local agent = skynet.newservice(agent_service)
        skynet.send(agent, "lua", "start", { fd = new_fd, addr = addr, watchdog = skynet.self() })
    end)
    log.info("ws listening on 0.0.0.0:%d", ws_port)
    return "0.0.0.0", ws_port
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, ...)
        local f = assert(CMD[cmd], cmd)
        skynet.ret(skynet.pack(f(...)))
    end)
end)
