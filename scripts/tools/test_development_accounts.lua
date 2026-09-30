package.path = "scripts/framework/utils/?.lua;" .. package.path
local provider = require "development_accounts"
local token = string.rep("x", 32) -- synthetic unit-test input, not a configured credential
local accounts = provider.new({ { account_id = "test", token = token, player_id = "42" } })
assert(not provider.new({}).authenticate("test", token))
assert(not accounts.authenticate("unknown", token))
assert(not accounts.authenticate("test", ""))
assert(not accounts.authenticate("test", token .. "x"))
assert(not accounts.authenticate("test", string.rep("y", 32)))
local identity = assert(accounts.authenticate("test", token))
assert(identity.player_id == "42" and identity.account_id == "test" and identity.token == nil)
identity.player_id = "999"
assert(accounts.authenticate("test", token).player_id == "42")
assert(not pcall(provider.new, { { account_id = "test", token = "short", player_id = "42" } }))
assert(not pcall(provider.new, { { account_id = "test", token = token, player_id = "arbitrary:key" } }))
assert(not pcall(provider.new, {
    { account_id = "test", token = token, player_id = "42" },
    { account_id = "test", token = token, player_id = "43" },
}))
print("development account provider: 10 checks passed")
