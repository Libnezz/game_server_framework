local json = require "json"
local definitions = require "exploration_definitions"
local M = {}
local MAX_REVISION = 9007199254740991
local function integer(v, min, max) return type(v) == "number" and v == math.floor(v) and v >= min and v <= max end
local function identity(id) assert(type(id) == "string" and #id > 0 and #id <= 64 and id:match("^%d+$"), "invalid exploration identity") end
local function array(value)
    assert(type(value) == "table", "invalid exploration array")
    local count = 0
    for k in pairs(value) do assert(integer(k, 1, #value), "invalid exploration array key"); count = count + 1 end
    assert(count == #value, "sparse exploration array")
end
function M.validate(id, value)
    identity(id)
    assert(type(value) == "table" and value.player_id == id and value.schema_version == 1
        and integer(value.revision, 1, MAX_REVISION), "invalid exploration document")
    array(value.goals); assert(#value.goals == 1, "unsupported exploration goals")
    local goal = value.goals[1]
    assert(type(goal) == "table", "invalid exploration goal")
    local definition = definitions.get(goal.goal_id, goal.definition_version)
    array(goal.completed_point_ids)
    assert(#goal.completed_point_ids > 0 and #goal.completed_point_ids <= #definition.point_ids, "invalid exploration completion")
    local ids = {}
    for _, point in ipairs(goal.completed_point_ids) do
        assert(integer(point, 1, 2147483647) and definitions.contains(definition, point) and not ids[point], "invalid exploration member")
        ids[point] = true
    end
    return value
end
local function snapshot(value)
    local goal = value.goals[1]
    local ids = {}; for i, id in ipairs(goal.completed_point_ids) do ids[i] = id end
    table.sort(ids)
    return { schema_version = 1, goal_id = goal.goal_id, definition_version = goal.definition_version,
        revision = value.revision, completed_point_ids = ids, phase = #ids == 0 and 1 or (#ids == 2 and 3 or 2) }
end
function M.new(store)
    local function read(id)
        identity(id)
        local row = store.read(id)
        if not row then return { player_id = id, schema_version = 1, revision = 0,
            goals = { { goal_id = 1, definition_version = 1, completed_point_ids = {} } } } end
        local ok, value = pcall(json.decode, row.payload)
        assert(ok, "malformed exploration document")
        M.validate(id, value)
        assert(row.schema_version == value.schema_version and row.revision == value.revision, "exploration metadata mismatch")
        return value
    end
    return {
        read = function(id, goal_id, version)
            definitions.get(goal_id, version)
            return snapshot(read(id))
        end,
        record = function(id, goal_id, version, point, expected_revision)
            local definition = definitions.get(goal_id, version)
            assert(integer(point, 1, 2147483647) and definitions.contains(definition, point), "invalid exploration point")
            assert(integer(expected_revision, 0, MAX_REVISION), "invalid expected exploration revision")
            local current = read(id)
            local function result(code, value) return { result = code, state = snapshot(value) } end
            local function completed(value)
                for _, p in ipairs(value.goals[1].completed_point_ids) do if p == point then return true end end
                return false
            end
            if completed(current) then return result(2, current) end
            if current.revision ~= expected_revision then return result(3, current) end
            assert(current.revision < MAX_REVISION, "exploration revision exhausted")
            table.insert(current.goals[1].completed_point_ids, point)
            table.sort(current.goals[1].completed_point_ids)
            current.revision = current.revision + 1
            M.validate(id, current)
            local written
            if expected_revision == 0 then written = store.try_create(id, 1, 1, json.encode(current))
            else written = store.compare_and_swap(id, 1, expected_revision, json.encode(current)) end
            local confirmed = read(id) -- Success only after a valid durable snapshot is available.
            if written then
                assert(completed(confirmed), "exploration write not visible")
                return result(1, confirmed)
            end
            return result(completed(confirmed) and 2 or 3, confirmed)
        end,
    }
end
return M
