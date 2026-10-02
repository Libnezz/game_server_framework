return {
    services = { { name = "testmodule" }, { name = "echo" } },
    protocols = { "scripts/framework/protos/networkpacket.proto", "scripts/framework/protos/test.proto" },
    config_tables = { "Item", "Reward" },
}
