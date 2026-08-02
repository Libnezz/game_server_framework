-- 配置加载服务：加载 datas/ 下的 JSON 数值配置表到 sharedata，支持热更
local skynet = require "skynet"
local sharedata = require "skynet.sharedata"
local json = require "json"

-- 配置表清单：datas/ 下需要加载的表名（对应 <name>.json，随项目扩展）
local CONFIG_FILES = {
    "Item",
    "Reward",
}

-- 配置目录，可在 etc/config 中通过 config_path 覆盖
local config_path = skynet.getenv("config_path") or "datas/"

-- 记录已加载的表，热更时用 update（重复 new 会断言）
local loaded = {}

local function load_config(name)
    local path = config_path .. name .. ".json"
    local f = assert(io.open(path, "rb"), string.format("open config failed: %s", path))
    local text = f:read("*a")
    f:close()
    local data = assert(json.decode(text), string.format("invalid json: %s", path))
    local count = type(data) == "table" and #data or 0
    if loaded[name] then
        sharedata.update(name, data)
        skynet.error(string.format("config reloaded: %s (%d entries)", name, count))
    else
        sharedata.new(name, data)
        loaded[name] = true
        skynet.error(string.format("config loaded: %s (%d entries)", name, count))
    end
end

local function reload_all()
    for _, name in ipairs(CONFIG_FILES) do
        load_config(name)
    end
end

skynet.start(function()
    reload_all()

    skynet.dispatch("lua", function(session, source, cmd)
        if cmd == "reload" then
            reload_all()
            skynet.ret(skynet.pack("ok"))
        elseif cmd == "status" then
            skynet.ret(skynet.pack(CONFIG_FILES))
        else
            skynet.error(string.format("configservice: unknown command %q", tostring(cmd)))
        end
    end)
end)
