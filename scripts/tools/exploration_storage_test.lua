local skynet = require "skynet"
require "skynet.manager"
local db = require "db"
local json = require "json"
local documents = require "mysql_document_store"
local module = require "player_exploration_repository"
local id = assert(skynet.getenv("exploration_test_id"))
assert(id:match("^9901%d+$") and #id <= 60, "isolated identity required")
local phase = assert(skynet.getenv("exploration_test_phase"))
local owned = {}
local function rejected(action) assert(not pcall(action), "operation must fail") end
local function cleanup()
    for key in pairs(owned) do db.mysql_execute("DELETE FROM player_exploration WHERE record_id=" .. db.mysql_quote(key)) end
end
skynet.start(function()
    skynet.newservice("mysqlservice")
    local ok, err = pcall(function()
        local store = documents.new({query=db.mysql_query,execute=db.mysql_execute,quote=db.mysql_quote,
            insert_if_absent=db.mysql_insert_if_absent}, "player_exploration")
        local repo = module.new(store)
        if phase == "write" then
            assert(not store.read(id)); owned[id] = true
            assert(repo.read(id,1,1).revision == 0 and not store.read(id))
            assert(repo.record(id,1,1,3002,0).result == 1)
            assert(repo.record(id,1,1,3002,0).result == 2)
            assert(repo.record(id,1,1,3001,0).result == 3)
            -- Two independently reading writers race on the first row. Loser rereads and retries.
            local race_id = id .. "1"; assert(not store.read(race_id)); owned[race_id] = true
            local done, failures, replies = 0, {}, {}
            for index, point in ipairs({3001,3002}) do
                skynet.fork(function()
                    local success, result = pcall(function() return module.new(store).record(race_id,1,1,point,0) end)
                    if success then replies[index] = result else failures[#failures+1] = result end
                    done = done + 1
                end)
            end
            while done < 2 do skynet.sleep(1) end
            assert(#failures == 0, "concurrent writer failed: " .. table.concat(failures, " | "))
            local winner = repo.read(race_id,1,1); assert(winner.revision == 1 and #winner.completed_point_ids == 1)
            assert((replies[1].result == 1 and replies[2].result == 3) or (replies[2].result == 1 and replies[1].result == 3))
            local missing = winner.completed_point_ids[1] == 3001 and 3002 or 3001
            assert(repo.record(race_id,1,1,missing,1).state.phase == 3)
            assert(repo.record(race_id,1,1,missing,0).result == 2)
            -- A stale conditional update cannot overwrite the winning complete document.
            assert(not store.compare_and_swap(race_id,1,1,"{}"))
            assert(repo.read(race_id,1,1).revision == 2)
            local broken = id .. "2"; assert(not store.read(broken)); owned[broken] = true
            repo.record(broken,1,1,3001,0)
            db.mysql_execute("UPDATE player_exploration SET revision=9 WHERE record_id=" .. db.mysql_quote(broken))
            rejected(function() repo.record(broken,1,1,3002,9) end)
            local absent = documents.new({query=db.mysql_query,execute=db.mysql_execute,quote=db.mysql_quote}, "exploration_missing_table")
            rejected(function() module.new(absent).read(id,1,1) end)
            db.mysql_execute("DELETE FROM player_exploration WHERE record_id=" .. db.mysql_quote(race_id))
            db.mysql_execute("DELETE FROM player_exploration WHERE record_id=" .. db.mysql_quote(broken))
            owned[race_id], owned[broken], owned[id] = nil, nil, nil -- retain one-point state for new process/restart
        elseif phase == "read" then
            owned[id] = true
            local saved = repo.read(id,1,1); assert(saved.revision == 1 and saved.completed_point_ids[1] == 3002)
            assert(repo.record(id,1,1,3001,1).state.phase == 3)
            assert(module.new(store).read(id,1,1).revision == 2)
            cleanup(); owned[id] = nil
        else error("invalid test phase") end
    end)
    if not ok then pcall(cleanup); io.stdout:write("EXPLORATION_STORAGE_FAIL: ", tostring(err), "\n")
    else io.stdout:write("EXPLORATION_STORAGE_PASS: ",phase,"\n") end
    io.stdout:flush(); skynet.abort()
end)
