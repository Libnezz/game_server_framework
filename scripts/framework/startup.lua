-- 框架服务启动清单：按依赖顺序排列，main.lua 依此启动
-- name: 服务名（按 luaservice 查找）；args: 启动参数
-- 注：logservice 由 skynet 内核根据 logger 配置自动启动，不需要在这里登记
return {
    { name = "debug_console", args = { 8000 } }, -- 支持性服务：调试控制台
    { name = "configservice" },                  -- 基础通用服务：配置加载器（datas/ 读表）
    { name = "protoservice" },                   -- 基础通用服务：协议加载器（.proto 解析）
    { name = "watchdog" },                       -- 基础通用服务：连接管理（gate + agent 的桥）
    { name = "echo" },                           -- 占位业务服务（验证链路，后续替换为真实业务）
}
