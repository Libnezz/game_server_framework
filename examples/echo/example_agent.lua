local skynet = require "skynet"
local websocket = require "http.websocket"
local proto = require "proto"
local rpc = require "rpc"
local kind = "Game.Framework.Network.NetworkPacket"
local handlers = {
    message = function(id, data)
        local session, name = 0, ""
        local ok, payload = pcall(function()
            local packet = proto.decode(kind, data)
            session, name = packet.session_id or 0, packet.protocol_name or ""
            if session == 0 and name == "Heartbeat" then return "" end
            assert(session > 0 and name == "TestRequest", "example only allows TestRequest")
            return rpc.dispatch(name, packet.payload)
        end)
        websocket.write(id, proto.encode(kind, { session_id = session, protocol_name = name,
            payload = ok and payload or "", error_code = ok and 0 or 1,
            error_msg = ok and "" or "request rejected", timestamp = os.time() }), "binary")
    end,
    close = function() skynet.exit() end,
    error = function() end,
}
skynet.start(function()
    skynet.dispatch("lua", function(session, source, cmd, conf)
        assert(cmd == "start")
        skynet.fork(function() websocket.accept(conf.fd, handlers, "ws", conf.addr); skynet.exit() end)
        skynet.ret(skynet.pack(true))
    end)
end)
