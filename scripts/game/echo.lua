-- 占位业务服务：验证服务间消息链路（后续会被真实业务服务替换）
local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command, payload)
        if command == "echo" then
            skynet.ret(skynet.pack(payload))
        else
            skynet.error(string.format("echo service: unknown command %q", tostring(command)))
        end
    end)
    skynet.error(string.format("echo service started, addr = %s", skynet.address(skynet.self())))
end)
