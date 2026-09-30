package.path = "scripts/framework/utils/?.lua;scripts/game/managers/?.lua;third_party/?.lua;" .. package.path
local json = require "json"
local profiles = require "player_profile_repository"
local document_store = require "mysql_document_store"
local checks = 0
local function test(name, action)
    local ok = pcall(action)
    assert(ok, "profile check failed: " .. name)
    checks = checks + 1
end
local function rejected(action) assert(not pcall(action), "operation must be rejected") end
local function seed(id)
    local value = profiles.seed(id, 321)
    value.nickname, value.level, value.exp, value.revision = "Test O'旅行者", 7, 345, 4
    value.total_login_count, value.last_login_unix_seconds = 12, 1790770000
    value.items = { { item_id = 1001, count = 5 }, { item_id = 1002, count = 6 } }
    return value
end
local function memory_store()
    local rows, creates = {}, 0
    return {
        read = function(id) return rows[id] end,
        create_if_absent = function(id, version, revision, payload)
            creates = creates + 1
            if not rows[id] then rows[id] = { schema_version = version, revision = revision, payload = payload } end
        end,
        rows = rows, creates = function() return creates end,
    }
end

test("complete seed persists once", function()
    local store, count = memory_store(), 0
    local repo = profiles.new(store, function(id) count = count + 1; return seed(id) end)
    local first, again = repo.load_or_create("42"), repo.load_or_create("42")
    assert(count == 1 and store.creates() == 1 and again.exp == 345 and again.items[2].count == 6)
    first.items[1].count = 99
    assert(repo.read("42").items[1].count == 5)
end)
test("concurrent creation returns winner", function()
    local store = memory_store()
    store.create_if_absent = function(id)
        local winner = seed(id); winner.coins = 999
        store.rows[id] = { schema_version = 1, revision = 4, payload = json.encode(winner) }
    end
    assert(profiles.new(store, seed).load_or_create("42").coins == 999)
end)
test("database outage cannot synthesize profile", function()
    local store = memory_store()
    store.read = function() error("database offline") end
    rejected(function() profiles.new(store, function() error("must not seed") end).load_or_create("42") end)
    assert(store.creates() == 0)
end)
test("read missing document never creates", function()
    local store = memory_store()
    rejected(function() profiles.new(store, seed).read("42") end)
    assert(store.creates() == 0)
end)
for _, scenario in ipairs({
    { "malformed JSON", function() return "invalid-json" end },
    { "unknown schema", function(v) v.schema_version = 2 end },
    { "different player", function(v) v.player_id = "43" end },
    { "missing field", function(v) v.total_login_count = nil end },
    { "negative balance", function(v) v.coins = -1 end },
    { "oversized balance", function(v) v.coins = 2147483648 end },
    { "zero level", function(v) v.level = 0 end },
    { "excess experience", function(v) v.exp = 700 end },
    { "fractional revision", function(v) v.revision = 1.5 end },
    { "duplicate inventory", function(v) v.items[2].item_id = v.items[1].item_id end },
    { "zero item count", function(v) v.items[1].count = 0 end },
    { "keyed inventory", function(v) v.items = { bad = { item_id = 2, count = 1 } } end },
    { "invalid nickname UTF8", function(v) v.nickname = "\xff" end },
    { "invalid login time", function(v) v.last_login_unix_seconds = -1 end },
}) do
    test(scenario[1] .. " fails without replacement", function()
        local store, value = memory_store(), seed("42")
        local raw = scenario[2](value) or json.encode(value)
        store.rows["42"] = { schema_version = 1, revision = value.revision, payload = raw }
        rejected(function() profiles.new(store, seed).load_or_create("42") end)
        assert(store.creates() == 0 and store.rows["42"].payload == raw)
    end)
end
test("metadata mismatch", function()
    local store = memory_store()
    store.rows["42"] = { schema_version = 1, revision = 9, payload = json.encode(seed("42")) }
    rejected(function() profiles.new(store, seed).read("42") end)
end)
test("failed creation never returns seed", function()
    local store = memory_store()
    store.create_if_absent = function() error("write failed") end
    rejected(function() profiles.new(store, seed).load_or_create("42") end)
end)
test("deleted row after creation", function()
    local store = memory_store()
    store.create_if_absent = function() end
    rejected(function() profiles.new(store, seed).load_or_create("42") end)
end)
test("document store rejects SQL identifiers", function()
    rejected(function() document_store.new({}, "profiles;DROP TABLE profiles") end)
end)
test("database error result is not missing row", function()
    local store = document_store.new({ quote = function(v) return "'" .. v .. "'" end,
        query = function() return { badresult = true } end }, "player_profiles")
    rejected(function() store.read("42") end)
end)
test("numeric identity boundary", function()
    rejected(function() profiles.validate("42:bad", seed("42")) end)
end)
print("player profile repository: " .. checks .. " checks passed")
