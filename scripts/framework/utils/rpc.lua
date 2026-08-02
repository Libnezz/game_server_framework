-- RPC 分发辅助：业务服务注册协议、agent 按协议名路由调用
local skynet = require "skynet"

local M = {}

-- 业务服务调用：注册自己处理的协议名（可多个）
function M.register(...)
    -- ".router" 是 C 内核本地名，可直接按字符串发送（与 skynet.call(".launcher", ...) 同理）
    return skynet.call(".router", "lua", "register", ...)
end

-- agent 调用：按协议名路由到目标业务服务，返回其响应（编码后的字节）
function M.dispatch(protocol_name, payload)
    local module = skynet.call(".router", "lua", "lookup", protocol_name)
    return skynet.call(module, "lua", protocol_name, payload)
end

return M
