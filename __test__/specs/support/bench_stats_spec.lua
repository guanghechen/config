local harness = require("__test__.support.harness")
local Stats = require("__test__.bench.stats")
local t = harness.new()

local root = assert(vim.uv.cwd()) ---@type string
local cases = vim.json.decode(table.concat(vim.fn.readfile(root .. "/__test__/fixtures/bench/stats_cases.json"), "\n"))

---JSON null becomes nil, as the Lua summary reports absent values.
---@param value                         any
---@return any
local function absent(value)
  if value == vim.NIL then
    return nil
  end
  if type(value) == "table" then
    local copy = {}
    for key, item in pairs(value) do
      copy[key] = absent(item)
    end
    return copy
  end
  return value
end

for _, case in ipairs(cases) do
  t:test("summary matches the shared statistics fixture: " .. case.name, function()
    local values = vim.deepcopy(case.values)
    t.assert_same(absent(case.summary), Stats.summary(values))
    t.assert_same(case.values, values, "input left unchanged")
  end)
end

t:run()
