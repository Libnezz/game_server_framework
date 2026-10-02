-- Trusted product definition. Client duration/position/completion claims are not economic proof.
local M = {}
local points = { 3001, 3002 }
function M.get(goal_id, version)
    assert(goal_id == 1 and version == 1, "unsupported exploration definition")
    return { id = 1, version = 1, point_ids = { points[1], points[2] } }
end
function M.contains(definition, id)
    for _, value in ipairs(definition.point_ids) do if value == id then return true end end
    return false
end
return M
