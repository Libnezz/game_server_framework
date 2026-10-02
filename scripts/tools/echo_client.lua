-- 测试客户端（开发期工具）：WebSocket 连接，发送 NetworkPacket(TestRequest)，打印响应
-- 用法：cd /app && bash scripts/tools/run_test_client.sh
io.stdout:setvbuf("line")
package.cpath = "skynet/luaclib/?.so"
package.path = "skynet/lualib/?.lua;third_party/?.lua;third_party/lua-protobuf/?.lua"

local socket = require "client.socket"
local pb = require "pb"
local protoc = require "protoc"

-- 加载协议（与 protoservice 一致）
local parser = protoc.new()
parser:loadfile("scripts/framework/protos/networkpacket.proto")
parser:loadfile("scripts/framework/protos/test.proto")
pb.option("enum_as_value")
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

local function send_heartbeat()
    local packet = pb.encode("Game.Framework.Network.NetworkPacket", {
        session_id = 0, protocol_name = "Heartbeat", timestamp = os.time(),
    })
    socket.send(fd, ws_frame(2, packet))
    local opcode, bytes = read_frame()
    assert(opcode == 2, "heartbeat response must be a binary frame")
    local reply = pb.decode("Game.Framework.Network.NetworkPacket", bytes)
    assert(reply.session_id == 0 and reply.protocol_name == "Heartbeat" and reply.error_code == 0,
        "heartbeat response did not match the NetworkPacket contract")
    io.write("heartbeat envelope ok\n")
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
    assert(op == 2, "response must be binary")
    assert(pkt.session_id == session_seq, "response session_id does not match request")
    assert(pkt.protocol_name == protocol_name, "response protocol_name does not match request")
    io.write(string.format("recv session=%s protocol=%s error_code=%s\n",
        tostring(pkt.session_id), tostring(pkt.protocol_name), tostring(pkt.error_code)))
    if pkt.error_code ~= 0 then
        error(string.format("server error (session=%s code=%s): %s",
            tostring(pkt.session_id), tostring(pkt.error_code), pkt.error_msg))
    end
    assert(pkt.session_id == session_seq, "response session_id does not match request")
    assert(pkt.protocol_name == protocol_name, "response protocol_name does not match request")
    return pb.decode(resp_type, pkt.payload)
end

local result = rpc_call("TestRequest", "TestRequest", {message="framework split"}, "TestResponse")
assert(result.result == "echo:framework split")
send_heartbeat()
socket.close(fd)
print("FRAMEWORK_ECHO_PASS heartbeat and correlated response")