-- 测试客户端（开发期工具）：连接游戏服务端，发送一条消息并打印回显
-- 用法：cd /app && ./skynet/3rd/lua/lua scripts/tools/test_client.lua
io.stdout:setvbuf("line")
package.cpath = "skynet/luaclib/?.so"

local socket = require "client.socket"
io.write("module: ", type(socket), ", connect: ", type(socket.connect), ", version: ", _VERSION, "\n")
io.flush()

local host = arg[1] or "127.0.0.1"
local port = tonumber(arg[2]) or 8888

io.write(string.format("connecting to %s:%d ...\n", host, port))
io.flush()
local ok, fd = pcall(socket.connect, host, port)
if not ok then
    io.write("connect error: " .. tostring(fd) .. "\n")
    os.exit(1)
end
assert(fd, "connect returned nil")
io.write(string.format("connected, fd=%d\n", fd))
io.flush()

local function send_package(fd, msg)
    local package = string.pack(">s2", msg)
    socket.send(fd, package)
end

local function recv_package()
    local last = ""
    while true do
        if #last >= 2 then
            local size = last:byte(1) * 256 + last:byte(2)
            if #last >= size + 2 then
                return last:sub(3, 2 + size)
            end
        end
        local r = socket.recv(fd)
        if r == "" then
            error("server closed")
        end
        last = last .. (r or "")
    end
end

local msg = arg[3] or "hello from test client"
io.write("send: " .. msg .. "\n")
io.flush()
send_package(fd, msg)
io.write("recv: " .. recv_package() .. "\n")
io.flush()

socket.close(fd)
