-- Infrastructure only; the application supplies business services.
return {
    { name = "configservice" }, { name = "protoservice" },
    { name = "redisservice" }, { name = "mysqlservice" }, { name = "router" },
}
