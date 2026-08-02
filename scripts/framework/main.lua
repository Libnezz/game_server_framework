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

    -- 验证 Redis 链路
    local db = require "db"
    local okr, rr = pcall(db.redis, "SET", "framework:boot", os.time())
    if okr then
        local v = db.redis("GET", "framework:boot")
        log.info("redis self-check ok: framework:boot = %s", tostring(v))
    else
        log.error("redis self-check failed: %s", tostring(rr))
    end

    -- 验证 MySQL 链路（建表 + 插入 + 查询）
    local okm, rm = pcall(function()
        db.mysql_execute("CREATE TABLE IF NOT EXISTS framework_selfcheck (id INT AUTO_INCREMENT PRIMARY KEY, note VARCHAR(64), ts BIGINT)")
        db.mysql_execute("INSERT INTO framework_selfcheck (note, ts) VALUES ('boot', " .. os.time() .. ")")
        return db.mysql_query("SELECT note, ts FROM framework_selfcheck ORDER BY id DESC LIMIT 1")
    end)
    if okm and rm and rm[1] then
        log.info("mysql self-check ok: %s", tostring(rm[1].note))
    else
        log.error("mysql self-check failed: %s", tostring(rm))
    end

    -- 验证 playermgr
    local online = skynet.call(services.playermgr, "lua", "online")
    log.info("playermgr online: %d", online)

    -- 打开 WebSocket 监听（端口见 etc/config 的 ws_port）
    local addr, port = skynet.call(services.watchdog, "lua", "start")
    log.info("ws listening on %s:%s", tostring(addr), tostring(port))

    -- 验证服务间消息往返
    local msg = skynet.call(services.echo, "lua", "echo", "framework alive")
    log.info("echo service responded: %s", tostring(msg))
end)
