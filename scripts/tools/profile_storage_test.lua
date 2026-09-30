-- Standalone Skynet/MySQL integration test. No listener, no client credentials.
local skynet = require "skynet"
require "skynet.manager"
local db = require "db"
local json = require "json"
local profile_module = require "player_profile_repository"
local document_store = require "mysql_document_store"
local proto = require "proto"
local id = assert(skynet.getenv("profile_test_id"))
assert(id:match("^9900%d+$") and #id <= 60, "test identity must use reserved numeric prefix")
local phase = assert(skynet.getenv("profile_test_phase"))
local owned = {}

local function seed(player_id)
    local value = profile_module.seed(player_id, 321)
    value.nickname, value.level, value.exp, value.revision = "Test O'旅行者", 7, 345, 4
    value.total_login_count, value.last_login_unix_seconds = 12, 1790770000
    value.items = { { item_id = 1001, count = 5 }, { item_id = 1002, count = 6 } }
    return value
end
local function verify(value)
    assert(value.player_id == id and value.schema_version == 1 and value.revision == 4)
    assert(value.nickname == "Test O'旅行者" and value.level == 7 and value.exp == 345 and value.coins == 321)
    assert(value.total_login_count == 12 and value.last_login_unix_seconds == 1790770000)
    assert(#value.items == 2 and value.items[1].item_id == 1001 and value.items[1].count == 5 and value.items[2].count == 6)
end
local function rejected(action) assert(not pcall(action), "operation must fail closed") end
local function cleanup()
    for record_id in pairs(owned) do
        db.mysql_execute("DELETE FROM player_profiles WHERE record_id=" .. db.mysql_quote(record_id))
    end
end

skynet.start(function()
    skynet.newservice("mysqlservice")
    local ok, err = pcall(function()
        local store = document_store.new({ query = db.mysql_query, execute = db.mysql_execute, quote = db.mysql_quote }, "player_profiles")
        local repo = profile_module.new(store, seed)
        if phase == "write" then
            assert(not store.read(id), "test identity already exists")
            owned[id] = true
            verify(repo.load_or_create(id))
            local different = seed(id); different.coins = 999
            store.create_if_absent(id, 1, 4, json.encode(different))
            verify(repo.read(id)) -- Duplicate creation cannot replace the original row.
            local snapshot = repo.read(id); snapshot.items[1].count = 99
            verify(repo.read(id))
            local corrupt_id = id .. "1"
            assert(not store.read(corrupt_id)); owned[corrupt_id] = true
            local fixture = seed(corrupt_id)
            store.create_if_absent(corrupt_id, 1, 4, json.encode(fixture))
            db.mysql_execute("UPDATE player_profiles SET revision=9 WHERE record_id=" .. db.mysql_quote(corrupt_id))
            local before = store.read(corrupt_id).payload
            rejected(function() repo.load_or_create(corrupt_id) end)
            assert(store.read(corrupt_id).payload == before)
            local unknown = seed(corrupt_id); unknown.schema_version = 2
            db.mysql_execute("UPDATE player_profiles SET schema_version=2,revision=4,body=" .. db.mysql_quote(json.encode(unknown)) ..
                " WHERE record_id=" .. db.mysql_quote(corrupt_id))
            rejected(function() repo.read(corrupt_id) end)
            rejected(function() store.create_if_absent(id .. "2", 1, 1, "not-json") end)
            assert(not store.read(id .. "2"))
            local absent = document_store.new({ query = db.mysql_query, execute = db.mysql_execute, quote = db.mysql_quote }, "profile_test_table_does_not_exist")
            rejected(function() absent.read(id) end)
            db.mysql_execute("DELETE FROM player_profiles WHERE record_id=" .. db.mysql_quote(corrupt_id))
            owned[corrupt_id], owned[id] = nil, nil -- Keep only the valid row for a NEW Skynet process to read.
        elseif phase == "read" then
            owned[id] = true
            local reopened = profile_module.new(store, function() error("persisted profile must not be seeded again") end)
            verify(reopened.load_or_create(id))
            local encoded = proto.encode("Game.Framework.Network.PlayerProfileResponse", reopened.read(id))
            verify(proto.decode("Game.Framework.Network.PlayerProfileResponse", encoded))
            cleanup()
            owned[id] = nil
        else
            error("unknown profile test phase")
        end
    end)
    if not ok then
        pcall(cleanup)
        io.stdout:write("PROFILE_STORAGE_TEST_FAIL: ", tostring(err), "\n")
    else
        io.stdout:write("PROFILE_STORAGE_TEST_PASS: ", phase, "\n")
    end
    io.stdout:flush() -- skynet.abort can stop the asynchronous log service before it drains.
    skynet.abort()
end)
