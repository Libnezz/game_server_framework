-- 测试客户端（开发期工具）：WebSocket 连接，发送 NetworkPacket(TestRequest)，打印响应
-- 用法：cd /app && bash scripts/tools/run_test_client.sh
io.stdout:setvbuf("line")
package.cpath = "skynet/luaclib/?.so"
package.path = "skynet/lualib/?.lua;third_party/lua-protobuf/?.lua"

local socket = require "client.socket"
local pb = require "pb"
local protoc = require "protoc"

-- 加载协议（与 protoservice 一致）
local parser = protoc.new()
parser:loadfile("scripts/game/protos/networkpacket.proto")
parser:loadfile("scripts/game/protos/test.proto")
parser:loadfile("scripts/game/protos/player.proto")
protoc.reload()

local host = arg[1] or "127.0.0.1"
local port = tonumber(arg[2]) or 8888

io.write(string.format("connecting to %s:%d ...\n", host, port))
io.flush()

-- 连接 + WebSocket 握手
local fd = assert(socket.connect(host, port))
local key = "dGhlIHNhbXBsZSBub25jZQ==" -- RFC 6455 示例 key
local handshake = string.format(
    "GET / HTTP/1.1\r\nHost: %s:%d\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n",
    host, port, key)
socket.send(fd, handshake)

local header = ""
while not header:find("\r\n\r\n", 1, true) do
    local r = socket.recv(fd)
    if r == "" then
        error("server closed during handshake")
    end
    header = header .. (r or "")
end
local status_line = header:sub(1, header:find("\r\n", 1, true) - 1)
io.write("handshake: ", status_line, "\n")

-- 发送二进制帧（客户端必须 mask）
local function ws_frame(opcode, payload)
    local mask = "\x01\x02\x03\x04"
    local len = #payload
    local byte1 = 0x80 | opcode
    local header_part
    if len < 126 then
        header_part = string.char(byte1, 0x80 | len)
    elseif len < 65536 then
        header_part = string.char(byte1, 0x80 | 126) .. string.pack(">I2", len)
    else
        header_part = string.char(byte1, 0x80 | 127) .. string.pack(">I8", len)
    end
    local parts = {}
    for i = 1, len do
        parts[i] = string.char(string.byte(payload, i) ~ mask:byte((i - 1) % 4 + 1))
    end
    return header_part .. mask .. table.concat(parts)
end

-- 读取服务端帧（服务端不发 mask）
local last = ""
local function recv_exact(n)
    while #last < n do
        local r = socket.recv(fd)
        if r == "" then
            error("server closed")
        end
        last = last .. (r or "")
    end
    local ret = last:sub(1, n)
    last = last:sub(n + 1)
    return ret
end

local function read_frame()
    local b1, b2 = recv_exact(2):byte(1, 2)
    local opcode = b1 & 0x0F
    local masked = b2 & 0x80
    local len = b2 & 0x7F
    if len == 126 then
        len = string.unpack(">I2", recv_exact(2))
    elseif len == 127 then
        len = string.unpack(">I8", recv_exact(8))
    end
    local mask
    if masked ~= 0 then
        mask = recv_exact(4)
    end
    local payload = recv_exact(len)
    if mask then
        local parts = {}
        for i = 1, len do
            parts[i] = string.char(string.byte(payload, i) ~ mask:byte((i - 1) % 4 + 1))
        end
        payload = table.concat(parts)
    end
    return opcode, payload
end

local session_seq = 0
-- protocol_name 为业务协议短名（路由用），proto_type 为 protobuf 完整类型名（编解码用）
local function rpc_call(protocol_name, proto_type, payload_tbl, resp_type)
    session_seq = session_seq + 1
    local payload = pb.encode(proto_type, payload_tbl or {})
    local packet = pb.encode("Game.Framework.Network.NetworkPacket", {
        session_id = session_seq,
        protocol_name = protocol_name,
        payload = payload,
        timestamp = os.time(),
    })
    io.write(string.format("send %s(%d bytes)\n", protocol_name, #packet))
    io.flush()
    socket.send(fd, ws_frame(2, packet))

    local op, resp = read_frame()
    local pkt = pb.decode("Game.Framework.Network.NetworkPacket", resp)
    io.write(string.format("recv session=%s protocol=%s error_code=%s\n",
        tostring(pkt.session_id), tostring(pkt.protocol_name), tostring(pkt.error_code)))
    if pkt.error_code ~= 0 then
        error("server error: " .. pkt.error_msg)
    end
    return pb.decode(resp_type, pkt.payload)
end

-- 第一段会话：登录 → 查信息 → 加金币
local P = "Game.Framework.Network."
local login = rpc_call("LoginRequest", P .. "LoginRequest", { player_id = "10001" }, P .. "LoginResponse")
io.write(string.format("login ok: player=%s code=%s\n", login.player_id, tostring(login.code)))
local info = rpc_call("GetPlayerInfo", P .. "PlayerInfoRequest", nil, P .. "PlayerInfoResponse")
io.write(string.format("player info: coins=%s\n", tostring(info.coins)))
local add = rpc_call("AddCoins", P .. "AddCoinsRequest", { amount = 50 }, P .. "AddCoinsResponse")
io.write(string.format("add coins ok: now %s\n", tostring(add.coins)))

socket.close(fd)
io.write("--- reconnect ---\n")

-- 第二段会话：重连验证玩家数据持久化（playermgr 复用同一 player 实体）
local fd = assert(socket.connect(host, port))
socket.send(fd, handshake)
header = ""
while not header:find("\r\n\r\n", 1, true) do
    local r = socket.recv(fd)
    if r == "" then
        error("server closed during handshake")
    end
    header = header .. (r or "")
end

local login2 = rpc_call("LoginRequest", P .. "LoginRequest", { player_id = "10001" }, P .. "LoginResponse")
local info2 = rpc_call("GetPlayerInfo", P .. "PlayerInfoRequest", nil, P .. "PlayerInfoResponse")
io.write(string.format("reconnect player info: coins=%s\n", tostring(info2.coins)))

socket.close(fd)
