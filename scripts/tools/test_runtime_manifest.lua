package.path = "scripts/framework/utils/?.lua;" .. package.path
local validate = require("runtime_manifest").validate
local count = 0
local function bad(value) assert(not pcall(validate, value)); count = count + 1 end
validate({ services = {}, protocols = {"envelope.proto"}, config_tables = {} }); count = count + 1
bad({ services = {}, protocols = {}, config_tables = {} })
bad({ services = {}, protocols = {"x.proto", "x.proto"}, config_tables = {} })
bad({ services = {{name="a"}, {name="a"}}, protocols = {"x.proto"}, config_tables = {} })
bad({ services = {}, protocols = {"x.proto"}, config_tables = {"../escape"} })
bad({ services = {}, protocols = {[2]="x.proto"}, config_tables = {} })
bad({ services = {}, protocols = {"x.txt"}, config_tables = {} })
bad({ services = {{name="a",args=false}}, protocols = {"x.proto"}, config_tables = {} })
print("runtime manifest checks passed: " .. count)
