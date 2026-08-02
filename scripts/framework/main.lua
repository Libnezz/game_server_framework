-- 框架启动入口：编排生产环境下需要拉起的基础服务
local skynet = require "skynet"

skynet.start(function()
    skynet.error("framework booted")

    -- 调试控制台（运行时工具，生产环境也保留，用配置控制监听地址/端口）
    skynet.newservice("debug_console", 8000)

    -- 最小业务服务 + 消息往返验证
    local ping = skynet.newservice("ping")
    local resp = skynet.call(ping, "lua", "ping")
    skynet.error(string.format("ping service responded: %s", tostring(resp)))
end)
