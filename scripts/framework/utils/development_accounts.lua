-- Local synthetic accounts only. No default credentials and no client-selected identity.
local M = {}

function M.new(accounts)
    local by_name, identities = {}, {}
    for _, account in ipairs(accounts or {}) do
        assert(type(account.account_id) == "string" and #account.account_id > 0, "invalid account configuration")
        assert(type(account.token) == "string" and #account.token >= 32, "invalid account configuration")
        assert(type(account.player_id) == "string" and account.player_id:match("^%d+$"), "invalid account configuration")
        assert(not by_name[account.account_id] and not identities[account.player_id], "duplicate account configuration")
        by_name[account.account_id], identities[account.player_id] = account, true
    end
    return {
        authenticate = function(account_id, token)
            local account = by_name[account_id]
            if type(token) ~= "string" or #token > 256 or not account then return nil end
            -- Compare all bytes for equal-length synthetic tokens; this is not a production password system.
            local mismatch = #token ~ #account.token
            for i = 1, #account.token do
                mismatch = mismatch | (account.token:byte(i) ~ (token:byte(i) or 0))
            end
            if mismatch ~= 0 then return nil end
            return { account_id = account.account_id, player_id = account.player_id }
        end,
    }
end

function M.load(path)
    if not path or path == "" then return M.new({}) end
    local file = assert(io.open(path, "rb"), "development accounts file unavailable")
    local bytes = file:read("*a")
    file:close()
    -- Never report parser errors containing input or credentials.
    local ok, data = pcall(require("json").decode, bytes)
    assert(ok and type(data) == "table" and type(data.accounts) == "table", "invalid development accounts file")
    return M.new(data.accounts)
end

return M
