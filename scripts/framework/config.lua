-- 框架读表库：业务服务通过它读取 sharedata 配置表
local sharedata = require "skynet.sharedata"

local M = {}

-- 读取一张配置表，返回只读代理对象（可用 obj.key 访问）
-- 配置不存在时返回 nil
function M.get(name)
    local ok, obj = pcall(sharedata.query, name)
    if ok then
        return obj
    end
    return nil
end

-- 深拷贝为普通 Lua 表（适合遍历/整体传递，注意性能）
function M.copy(name)
    local ok, obj = pcall(sharedata.deepcopy, name)
    if ok then
        return obj
    end
    return nil
end

return M
