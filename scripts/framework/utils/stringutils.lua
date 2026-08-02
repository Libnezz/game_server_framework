-- 通用字符串工具：示例，后续按需扩展
local M = {}

local function escape_magic(s)
    return (s:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

-- 按分隔符拆分字符串
function M.split(str, sep)
    local parts = {}
    local plain = escape_magic(sep or ",")
    for part in string.gmatch(str, "[^" .. plain .. "]+") do
        table.insert(parts, part)
    end
    return parts
end

-- 去除首尾空白
function M.trim(str)
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.is_empty(str)
    return str == nil or str == ""
end

return M
