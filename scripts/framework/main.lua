-- 框架启动编排入口：skynet 完成进程级启动后，按启动清单依序拉起服务
local skynet = require "skynet"
local startup = require "startup"
local log = require "log"

skynet.start(function()
    log.info("framework booted")

    -- 按启动清单依序启动服务（newservice 会等待服务启动完成，天然保证先后）
    local services = {}
    for i, item in ipairs(startup) do
        local handle = skynet.newservice(item.name, table.unpack(item.args or {}))
        services[item.name] = handle
        log.info("startup %d/%d: %s ok", i, #startup, item.name)
    end

    -- 自检：读取一张配置表，验证读表链路
    local config = require "config"
    local items = config.get("Item")
    if items and items[1] then
        log.info("self-check: Item[1] = %s (id %s)", tostring(items[1].name), tostring(items[1].id))
    else
        log.error("self-check failed: Item config not found")
    end

    -- 验证 configd 热更接口
    local resp = skynet.call(services.configservice, "lua", "reload")
    log.info("config reload: %s", tostring(resp))

    -- 验证 protoservice 状态接口
    local protos = skynet.call(services.protoservice, "lua", "status")
    log.info("protoservice status: %s", table.concat(protos, ", "))

    -- 打开网络监听（gate 端口见 etc/config 的 gate_port）
    local addr, port = skynet.call(services.watchdog, "lua", "start")
    log.info("gate listening on %s:%s", tostring(addr), tostring(port))

    -- 验证服务间消息往返
    local msg = skynet.call(services.echo, "lua", "echo", "framework alive")
    log.info("echo service responded: %s", tostring(msg))
end)
