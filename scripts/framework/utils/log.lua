-- 框架日志库：级别过滤 + 格式化，经 skynet.error 由 logservice 统一输出
local skynet = require "skynet"

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
local min_level = LEVELS[skynet.getenv("log_level") or "info"] or LEVELS.info

local function emit(level, fmt, ...)
    if LEVELS[level] < min_level then
        return
    end
    skynet.error(string.format("[%s] %s", level:upper(), string.format(fmt, ...)))
end

local M = {}

function M.debug(fmt, ...) emit("debug", fmt, ...) end
function M.info(fmt, ...) emit("info", fmt, ...) end
function M.warn(fmt, ...) emit("warn", fmt, ...) end
function M.error(fmt, ...) emit("error", fmt, ...) end

return M
