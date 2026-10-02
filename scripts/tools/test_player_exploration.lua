package.path = "scripts/framework/utils/?.lua;scripts/game/managers/?.lua;third_party/?.lua;" .. package.path
local json = require "json"
local module = require "player_exploration_repository"
local documents = require "mysql_document_store"
local checks = 0
local function test(name, action) local ok, err = pcall(action); assert(ok, name .. ": " .. tostring(err)); checks = checks + 1 end
local function rejected(action) assert(not pcall(action), "must reject") end
local function memory()
    local rows, writes = {}, 0
    local store = {
        rows = rows, writes = function() return writes end,
        read = function(id) return rows[id] end,
        try_create = function(id, schema, revision, payload)
            if rows[id] then return false end
            writes = writes + 1; rows[id] = { schema_version = schema, revision = revision, payload = payload }; return true
        end,
        compare_and_swap = function(id, schema, revision, payload)
            if not rows[id] or rows[id].revision ~= revision or rows[id].schema_version ~= schema then return false end
            writes = writes + 1; rows[id] = { schema_version = schema, revision = revision + 1, payload = payload }; return true
        end,
    }
    return store
end
for _, reverse in ipairs({false, true}) do test("both orders " .. tostring(reverse), function()
    local store = memory(); local repo = module.new(store)
    assert(repo.read("42", 1, 1).revision == 0 and store.writes() == 0)
    local a, b = reverse and 3002 or 3001, reverse and 3001 or 3002
    local first = repo.record("42", 1, 1, a, 0)
    assert(first.result == 1 and first.state.revision == 1 and first.state.phase == 2)
    first.state.completed_point_ids[1] = 99
    local duplicate = repo.record("42", 1, 1, a, 0)
    assert(duplicate.result == 2 and duplicate.state.revision == 1 and store.writes() == 1)
    assert(repo.record("42", 1, 1, b, 0).result == 3)
    local last = repo.record("42", 1, 1, b, 1)
    assert(last.result == 1 and last.state.phase == 3 and last.state.revision == 2)
    assert(repo.record("42", 1, 1, b, 1).result == 2 and store.writes() == 2)
end) end
test("separate identity and reopen", function()
    local store = memory(); module.new(store).record("42", 1, 1, 3001, 0)
    assert(module.new(store).read("42", 1, 1).revision == 1)
    assert(module.new(store).read("43", 1, 1).revision == 0)
end)
test("creation race different point", function()
    local store = memory(); local create = store.try_create
    store.try_create = function(id)
        local winner = { player_id = id, schema_version = 1, revision = 1,
            goals = {{ goal_id = 1, definition_version = 1, completed_point_ids = {3002} }} }
        create(id, 1, 1, json.encode(winner)); return false
    end
    local repo = module.new(store); local reply = repo.record("42", 1, 1, 3001, 0)
    assert(reply.result == 3 and reply.state.completed_point_ids[1] == 3002)
    assert(repo.record("42", 1, 1, 3001, 1).state.phase == 3)
end)
test("CAS race rereads same-point winner", function()
    local store = memory(); local repo = module.new(store); repo.record("42", 1, 1, 3001, 0)
    local swap = store.compare_and_swap
    store.compare_and_swap = function(...) swap(...); return false end
    assert(repo.record("42", 1, 1, 3002, 1).result == 2)
end)
for _, request in ipairs({ {2,1,3001,0}, {1,2,3001,0}, {1,1,99,0}, {1,1,3001,-1}, {1,1,3001,0.5}, {1,1,3001,9007199254740992} }) do
    test("invalid request " .. checks, function()
        local store = memory(); local repo = module.new(store)
        rejected(function() repo.record("42", table.unpack(request)) end); assert(store.writes() == 0)
    end)
end
for _, mutate in ipairs({
    function(v) v.player_id = "43" end, function(v) v.schema_version = 2 end,
    function(v) v.revision = 1.5 end, function(v) v.goals[1].definition_version = 2 end,
    function(v) v.goals[1].completed_point_ids = {3001,3001} end,
    function(v) v.goals[1].completed_point_ids = {99} end,
    function(v) v.goals[1].completed_point_ids = {} end,
    function(v) v.goals[1].completed_point_ids = { bad = 3001 } end,
    function(v) v.goals = {} end,
}) do test("corrupt record " .. checks, function()
    local store = memory(); local repo = module.new(store); repo.record("42", 1, 1, 3001, 0)
    local value = json.decode(store.rows["42"].payload); mutate(value); store.rows["42"].payload = json.encode(value)
    local before = store.rows["42"].payload
    rejected(function() repo.record("42", 1, 1, 3002, 1) end)
    assert(store.rows["42"].payload == before and store.writes() == 1)
end) end
test("invalid JSON and metadata", function()
    local store = memory(); local repo = module.new(store); repo.record("42", 1, 1, 3001, 0)
    store.rows["42"].revision = 2; rejected(function() repo.read("42", 1, 1) end)
    store.rows["42"].payload = "invalid"; rejected(function() repo.read("42", 1, 1) end)
end)
test("DB read/write errors cannot confirm", function()
    local store = memory(); local repo = module.new(store)
    store.read = function() error("offline") end; rejected(function() repo.read("42", 1, 1) end)
    store = memory(); repo = module.new(store)
    store.try_create = function() error("write offline") end; rejected(function() repo.record("42", 1, 1, 3001, 0) end)
end)
test("conditional SQL and failures", function()
    local affected = 1; local sql
    local store = documents.new({ quote = function(v) return "'" .. v .. "'" end,
        insert_if_absent = function(value) sql = value; return { affected_rows = affected } end,
        execute = function(value) sql = value; return { affected_rows = affected } end }, "player_exploration")
    assert(store.try_create("42",1,1,"{}")); affected = 0; assert(not store.try_create("42",1,1,"{}"))
    affected = 1; assert(store.compare_and_swap("42",1,7,"{}"))
    assert(sql:find("revision=8",1,true) and sql:find("AND revision=7",1,true) and sql:find("AND schema_version=1",1,true))
    affected = 0; assert(not store.compare_and_swap("42",1,7,"{}"))
    affected = 2; rejected(function() store.compare_and_swap("42",1,7,"{}") end)
    rejected(function() store.compare_and_swap("42",1,0,"{}") end)
    rejected(function() store.compare_and_swap("42",1,9007199254740991,"{}") end)
    local failed = documents.new({ quote=function(v) return v end, execute=function() return {badresult=true} end,
        insert_if_absent=function() return {badresult=true} end }, "player_exploration")
    rejected(function() failed.try_create("42",1,1,"{}") end)
    rejected(function() failed.compare_and_swap("42",1,1,"{}") end)
end)
io.write("EXPLORATION_UNIT_PASS checks=", checks, "\n")
