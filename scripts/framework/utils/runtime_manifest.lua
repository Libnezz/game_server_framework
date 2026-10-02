-- The host owns business composition; the framework only validates and loads it.
local M = {}
function M.validate(value)
    assert(type(value) == "table", "application manifest required")
    for _, field in ipairs({"services", "protocols", "config_tables"}) do
        assert(type(value[field]) == "table", "manifest list required: " .. field)
        local count = 0
        for key in pairs(value[field]) do
            assert(type(key) == "number" and key >= 1 and key % 1 == 0, "manifest list must be an array")
            count = count + 1
        end
        assert(count == #value[field], "manifest list must be contiguous")
    end
    assert(#value.protocols > 0, "protocol manifest cannot be empty")
    local seen = {}
    for _, path in ipairs(value.protocols) do
        assert(type(path) == "string" and path:match("%.proto$") and not seen[path], "invalid/duplicate protocol path")
        seen[path] = true
    end
    seen = {}
    for _, item in ipairs(value.services) do
        assert(type(item) == "table" and type(item.name) == "string" and item.name:match("^[%w_]+$")
            and not seen[item.name], "invalid/duplicate application service")
        assert(item.args == nil or type(item.args) == "table", "service args must be a table")
        seen[item.name] = true
    end
    seen = {}
    for _, name in ipairs(value.config_tables) do
        assert(type(name) == "string" and name:match("^[%w_]+$") and not seen[name], "invalid/duplicate config table")
        seen[name] = true
    end
    return value
end
local cached
function M.get()
    if not cached then
        local name = assert(require("skynet").getenv("application_manifest"), "application_manifest must be configured")
        cached = M.validate(require(name))
    end
    return cached
end
return M
