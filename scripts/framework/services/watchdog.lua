-- 看门狗服务：连接生命周期管理（网络域 → 业务域的桥）
-- 职责：启动 gate、监听连接事件，为每个连接创建 agent，断线时清理
-- 预留：将来引入 agent 管理器后，创建/复用 agent 的逻辑从这里迁出（登录、重连）
local skynet = require "skynet"
local log = require "log"

local gate
local agents = {} -- fd -> agent 服务句柄

-- 配置（etc/config 中可覆盖）
local agent_service = skynet.getenv("agent_service") or "agent"
local gate_port = tonumber(skynet.getenv("gate_port") or "8888")
local gate_maxclient = tonumber(skynet.getenv("gate_maxclient") or "1024")

local SOCKET = {}

function SOCKET.open(fd, addr)
    log.info("new connection: fd=%d from %s", fd, tostring(addr))
    local agent = skynet.newservice(agent_service)
    agents[fd] = agent
    skynet.call(agent, "lua", "start", { gate = gate, client = fd, watchdog = skynet.self() })
end

local function close_agent(fd)
    local agent = agents[fd]
    agents[fd] = nil
    if agent then
        log.info("connection closed: fd=%d", fd)
        skynet.send(agent, "lua", "disconnect")
    end
end

function SOCKET.close(fd)
    close_agent(fd)
end

function SOCKET.error(fd, msg)
    log.info("connection error: fd=%d (%s)", fd, tostring(msg))
    close_agent(fd)
end

function SOCKET.warning(fd, size)
    -- 发送缓冲堆积告警，暂不处理
end

-- forward 之后数据包由 gate 直接转发给 agent，这里不需要处理
function SOCKET.data(fd, msg) end

local CMD = {}

function CMD.start()
    local ok, addr, port = pcall(skynet.call, gate, "lua", "open", {
        address = "0.0.0.0",
        port = gate_port,
        maxclient = gate_maxclient,
        nodelay = true,
        watchdog = skynet.self(),
    })
    if not ok then
        error(addr)
    end
    return addr, port
end

skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, subcmd, ...)
        if cmd == "socket" then
            local f = SOCKET[subcmd]
            if f then
                f(...)
            end
        else
            local f = assert(CMD[cmd], cmd)
            skynet.ret(skynet.pack(f(subcmd, ...)))
        end
    end)

    gate = skynet.newservice("gate")
end)
