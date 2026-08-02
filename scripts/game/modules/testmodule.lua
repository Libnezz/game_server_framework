-- 示例业务模块：注册并处理 TestRequest 协议，返回 TestResponse
local skynet = require "skynet"
local proto = require "proto"
local rpc = require "rpc"
local log = require "log"

local HANDLERS = {
    TestRequest = function(payload)
        local req = proto.decode("TestRequest", payload)
        log.info("testmodule: TestRequest message=%q", tostring(req.message))
        return proto.encode("TestResponse", { result = "echo:" .. req.message })
    end,
}

skynet.start(function()
    rpc.register("TestRequest")
    log.info("testmodule started, registered: TestRequest")

    skynet.dispatch("lua", function(session, source, protocol_name, payload)
        local f = HANDLERS[protocol_name]
        if not f then
            skynet.error(string.format("testmodule: unknown protocol %q", tostring(protocol_name)))
            return
        end
        skynet.ret(skynet.pack(f(payload)))
    end)
end)
