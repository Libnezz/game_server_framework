-- 自定义日志服务：接管 skynet 全部日志输出（text 消息），统一加时间戳写到 stdout
-- 注意：本服务内禁止调用 skynet.error（会发回给自己，形成循环），直接 io.write
local skynet = require "skynet"
require "skynet.manager"

local function timestamp()
    return os.date("%Y-%m-%d %H:%M:%S") .. string.format(".%02d", skynet.now() % 100)
end

-- text 协议默认未注册，需在 skynet.start 前显式注册（参考 skynet 官方 examples/userlog.lua）
skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    unpack = skynet.tostring,
    dispatch = function(_, address, msg)
        io.write(string.format("%s %s\n", timestamp(), tostring(msg)))
        io.flush()
    end,
}

-- system 消息（如日志重开信号）忽略即可
skynet.register_protocol {
    name = "SYSTEM",
    id = skynet.PTYPE_SYSTEM,
    unpack = function(...) return ... end,
    dispatch = function() end,
}

skynet.start(function() end)
