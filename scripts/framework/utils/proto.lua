-- Generic schema loader: paths come from the host application manifest.
-- 注意：lua-protobuf 的 schema 是每个服务 Lua VM 独立持有的，
-- 所以每个需要使用协议的服务，都要 require 本模块并调用 load_all()（幂等，通常启动时执行一次）。
-- 消息类型名需用完整名：带 package 的协议用 "包名.消息名"，如 "Game.Framework.Network.NetworkPacket"
local skynet = require "skynet"
local pb = require "pb"
local protoc = require "protoc"

-- Full paths allow the host to combine framework and product protocols.
local PROTO_FILES = require("runtime_manifest").get().protocols
local loaded = false

local M = {}

-- 加载全部协议（幂等，可安全重复调用）
function M.load_all()
    if loaded then
        return true
    end
    local parser = protoc.new()
    for _, name in ipairs(PROTO_FILES) do
        local path = name
        local ok, err = pcall(parser.loadfile, parser, path)
        if not ok then
            error(string.format("proto load failed: %s (%s)", path, tostring(err)))
        end
    end
    protoc.reload() -- 注册 google.protobuf 标准消息（如 Timestamp 等）
    loaded = true
    return true
end

-- 序列化（首次调用会自动加载协议）
function M.encode(type_name, tbl)
    M.load_all()
    return pb.encode(type_name, tbl)
end

-- 反序列化
function M.decode(type_name, data)
    M.load_all()
    return pb.decode(type_name, data)
end

-- 协议文件清单
function M.files()
    local ret = {}
    for _, name in ipairs(PROTO_FILES) do
        table.insert(ret, name)
    end
    return ret
end

return M
