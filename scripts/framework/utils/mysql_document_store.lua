-- Generic create-once JSON document storage; product schemas stay outside the framework.
-- Dependencies are injected so repository contracts can be tested without Skynet/MySQL.
local M = {}

function M.new(database, table_name)
    assert(type(table_name) == "string" and table_name:match("^[a-z][a-z0-9_]*$"), "invalid document table")
    local function record_key(id)
        assert(type(id) == "string" and #id > 0 and #id <= 64, "invalid document identity")
        return database.quote(id)
    end
    local function checked(result)
        assert(type(result) == "table" and not result.badresult, "document database operation failed")
        return result
    end
    return {
        read = function(id)
            local rows = checked(database.query("SELECT schema_version, revision, CAST(body AS CHAR CHARACTER SET utf8mb4) AS payload FROM " ..
                table_name .. " WHERE record_id=" .. record_key(id)))
            assert(#rows <= 1, "duplicate document identity")
            return rows[1]
        end,
        create_if_absent = function(id, schema_version, revision, payload)
            assert(math.type(schema_version) == "integer" and schema_version >= 1 and schema_version <= 2147483647, "invalid document schema")
            assert(math.type(revision) == "integer" and revision >= 1 and revision <= 9007199254740991, "invalid document revision")
            assert(type(payload) == "string" and #payload > 0, "invalid document payload")
            -- Atomic no-op on conflict, including simultaneous first authentication in another process.
            -- Never use REPLACE or an upsert that overwrites an existing player's document.
            return checked(database.execute("INSERT INTO " .. table_name ..
                " (record_id, schema_version, revision, body) VALUES (" .. record_key(id) .. "," ..
                schema_version .. "," .. revision .. "," .. database.quote(payload) ..
                ") ON DUPLICATE KEY UPDATE record_id=record_id"))
        end,
    }
end

return M
