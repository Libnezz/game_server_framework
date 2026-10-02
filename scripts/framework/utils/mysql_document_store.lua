-- Generic JSON document storage with conditional updates; schemas stay in business repositories.
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
    local function insert_sql(id, schema_version, revision, payload)
        assert(math.type(schema_version) == "integer" and schema_version >= 1 and schema_version <= 2147483647, "invalid document schema")
        assert(math.type(revision) == "integer" and revision >= 1 and revision <= 9007199254740991, "invalid document revision")
        assert(type(payload) == "string" and #payload > 0, "invalid document payload")
        return "INSERT INTO " .. table_name ..
            " (record_id, schema_version, revision, body) VALUES (" .. record_key(id) .. "," ..
            schema_version .. "," .. revision .. "," .. database.quote(payload) .. ")"
    end
    local function create(id, schema_version, revision, payload)
        return checked(database.execute(insert_sql(id, schema_version, revision, payload) .. " ON DUPLICATE KEY UPDATE record_id=record_id"))
    end
    local function changed(result)
        assert(result.affected_rows == 0 or result.affected_rows == 1, "unexpected document affected rows")
        return result.affected_rows == 1
    end
    return {
        read = function(id)
            local rows = checked(database.query("SELECT schema_version, revision, CAST(body AS CHAR CHARACTER SET utf8mb4) AS payload FROM " ..
                table_name .. " WHERE record_id=" .. record_key(id)))
            assert(#rows <= 1, "duplicate document identity")
            return rows[1]
        end,
        create_if_absent = create, -- Existing profile callers retain the raw-result contract.
        try_create = function(id, schema_version, revision, payload)
            -- Plain INSERT + explicit duplicate-key result: FOUND_ROWS makes no-op upserts report 1.
            return changed(checked(database.insert_if_absent(insert_sql(id, schema_version, revision, payload))))
        end,
        compare_and_swap = function(id, schema_version, expected_revision, payload)
            assert(math.type(schema_version) == "integer" and schema_version >= 1 and schema_version <= 2147483647, "invalid document schema")
            assert(math.type(expected_revision) == "integer" and expected_revision >= 1 and expected_revision < 9007199254740991, "invalid document revision")
            assert(type(payload) == "string" and #payload > 0, "invalid document payload")
            return changed(checked(database.execute("UPDATE " .. table_name .. " SET revision=" ..
                (expected_revision + 1) .. ", body=" .. database.quote(payload) .. " WHERE record_id=" .. record_key(id) ..
                " AND schema_version=" .. schema_version .. " AND revision=" .. expected_revision)))
        end,
    }
end

return M
