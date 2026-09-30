local json = require "json"
local M = {}

local function integer(value, minimum, maximum)
    return type(value) == "number" and value == math.floor(value) and value >= minimum and value <= maximum
end

local function player_identity(id)
    return type(id) == "string" and #id > 0 and #id <= 64 and id:match("^%d+$")
end

function M.validate(player_id, profile)
    assert(player_identity(player_id) and type(profile) == "table" and profile.player_id == player_id, "invalid profile identity")
    assert(profile.schema_version == 1 and integer(profile.revision, 1, 9007199254740991), "unsupported profile version")
    assert(type(profile.nickname) == "string" and profile.nickname:match("%S") and #profile.nickname <= 128 and utf8.len(profile.nickname), "invalid profile nickname")
    assert(integer(profile.level, 1, 1000) and integer(profile.exp, 0, 100 * profile.level - 1), "invalid profile growth")
    assert(integer(profile.coins, 0, 2147483647), "invalid profile balance")
    assert(integer(profile.total_login_count, 0, 2147483647) and integer(profile.last_login_unix_seconds, 0, 253402300799), "invalid profile login metadata")
    assert(type(profile.items) == "table", "invalid profile inventory")
    local ids, count = {}, 0
    for index, item in pairs(profile.items) do
        assert(integer(index, 1, 10000) and type(item) == "table", "invalid profile inventory")
        assert(integer(item.item_id, 1, 2147483647) and integer(item.count, 1, 2147483647) and not ids[item.item_id], "invalid profile inventory")
        ids[item.item_id], count = true, count + 1
    end
    assert(count == #profile.items, "invalid profile inventory")
    for index = 1, count do assert(profile.items[index], "invalid profile inventory") end
    return profile
end

function M.seed(player_id, legacy_coins)
    return M.validate(player_id, {
        player_id = player_id, schema_version = 1, revision = 1,
        nickname = "Test Traveler", level = 3, exp = 25, coins = legacy_coins,
        total_login_count = 0, last_login_unix_seconds = 0, items = {},
    })
end

function M.new(store, seed_factory)
    local function decode(id, record)
        assert(record, "profile record missing")
        local ok, profile = pcall(json.decode, record.payload)
        assert(ok, "profile record malformed")
        M.validate(id, profile)
        assert(record.schema_version == profile.schema_version and record.revision == profile.revision, "profile metadata mismatch")
        return profile -- Each DB read creates an independent snapshot, not a shared mutable seed.
    end
    return {
        read = function(id)
            assert(player_identity(id), "invalid profile identity")
            return decode(id, store.read(id))
        end,
        load_or_create = function(id)
            assert(player_identity(id), "invalid profile identity")
            local existing = store.read(id)
            if existing then return decode(id, existing) end
            local seed = M.validate(id, seed_factory(id))
            store.create_if_absent(id, seed.schema_version, seed.revision, json.encode(seed))
            -- Always read the winning row; a concurrent creator may have inserted a different seed.
            return decode(id, store.read(id))
        end,
    }
end

return M
