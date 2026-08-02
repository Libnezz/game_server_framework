-- 框架启动编排入口：skynet 完成进程级启动后，由这里拉起框架与业务服务
local skynet = require "skynet"

skynet.start(function()
    skynet.error("framework booted")

    -- 调试控制台（运行时工具，生产环境也保留，用配置控制监听地址/端口）
    skynet.newservice("debug_console", 8000)

    -- 拉起一个占位业务服务，并做一次服务间消息往返验证
    -- （skynet.call 是同步请求：main 服务 -> echo 服务 -> 返回响应）
    local echo = skynet.newservice("echo")
    local resp = skynet.call(echo, "lua", "echo", "framework alive")
    skynet.error(string.format("echo service responded: %s", tostring(resp)))
end)
