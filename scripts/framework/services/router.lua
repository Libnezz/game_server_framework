-- 协议路由器：维护 protocol_name → 业务服务 的映射，供 agent 分发
-- 业务服务启动时调用 rpc.register(协议名...) 注册；agent 通过 rpc.dispatch 路由调用
local skynet = require "skynet"
require "skynet.manager"
local log = require "log"

local routes = {} -- protocol_name -> service handle

local CMD = {}

-- 业务服务注册自己处理的协议（source 为调用方地址）
function CMD.register(source, ...)
    for i = 1, select("#", ...) do
        local name = select(i, ...)
        routes[name] = source
        log.info("route registered: %s -> %s", name, skynet.address(source))
    end
    return true
end

function CMD.lookup(protocol_name)
    local handle = routes[protocol_name]
    if not handle then
        error(string.format("protocol not registered: %s", tostring(protocol_name)))
    end
    return handle
end

skynet.start(function()
    skynet.name(".router", skynet.self())
    skynet.dispatch("lua", function(session, source, cmd, ...)
        if cmd == "register" then
            skynet.ret(skynet.pack(CMD.register(source, ...)))
        else
            local f = assert(CMD[cmd], cmd)
            skynet.ret(skynet.pack(f(...)))
        end
    end)
end)
