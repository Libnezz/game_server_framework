-- 协议加载服务：启动时统一加载并校验全部协议文件，提供状态查询
-- 说明：schema 由各服务 VM 独立持有，本服务负责"统一清单 + 启动校验 + fail-fast"；
-- 实际使用协议的服务各自 require "proto" 并调用 proto.load_all()（幂等）。
local skynet = require "skynet"
local proto = require "proto"

skynet.start(function()
    local ok, err = pcall(proto.load_all)
    if not ok then
        skynet.error(string.format("protoloader: load failed: %s", tostring(err)))
        skynet.abort()
    end
    skynet.error("protoloader: all protos loaded")

    -- 自检：TestRequest encode/decode 往返
    local ok2, msg = pcall(function()
        local bytes = proto.encode("TestRequest", { message = "framework alive" })
        local obj = proto.decode("TestRequest", bytes)
        return obj.message
    end)
    if ok2 then
        skynet.error(string.format("protoloader: self-check ok, roundtrip = %q", tostring(msg)))
    else
        skynet.error(string.format("protoloader: self-check failed: %s", tostring(msg)))
    end

    skynet.dispatch("lua", function(session, source, cmd)
        if cmd == "status" then
            skynet.ret(skynet.pack(proto.files()))
        else
            skynet.error(string.format("protoloader: unknown command %q", tostring(cmd)))
        end
    end)
end)
