local skynet = require "skynet"
local log = require "log"
local manifest = require("runtime_manifest").get()
skynet.start(function()
    local services = {}
    local function start(item)
        assert(not services[item.name], "duplicate infrastructure/application service: " .. item.name)
        services[item.name] = skynet.newservice(item.name, table.unpack(item.args or {}))
        log.info("startup: %s ok", item.name)
    end
    for _, item in ipairs(require "startup") do start(item) end
    for _, item in ipairs(manifest.services) do start(item) end
    start({ name = "watchdog" })
    local addr, port = skynet.call(services.watchdog, "lua", "start")
    log.info("application ready; ws listening on %s:%s", tostring(addr), tostring(port))
end)
