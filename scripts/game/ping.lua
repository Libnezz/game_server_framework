-- 最小业务服务：验证消息收发链路
local skynet = require "skynet"

skynet.start(function()
    skynet.dispatch("lua", function(session, source, command)
        if command == "ping" then
            skynet.ret(skynet.pack("pong"))
        else
            skynet.error(string.format("ping service: unknown command %q", tostring(command)))
        end
    end)
    skynet.error(string.format("ping service started, addr = %s", skynet.address(skynet.self())))
end)
