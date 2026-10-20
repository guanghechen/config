---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.data" ---@type string

local Stats = require("__test__.bench.stats")

local M = {}

---@param count                         integer
---@param dense                         ?boolean
---@return string[]
function M.labels(count, dense)
  local verbs =
    { "get", "set", "create", "update", "delete", "find", "read", "write", "parse", "load", "save", "resolve" }
  local nouns = {
    "User",
    "Buffer",
    "Completion",
    "Workspace",
    "Client",
    "Request",
    "Window",
    "Document",
    "Session",
    "Config",
    "Symbol",
    "Directory",
    "Command",
    "Variable",
    "File",
    "Tree",
  }
  local suffixes = {
    "Name",
    "Items",
    "Options",
    "Context",
    "State",
    "List",
    "Result",
    "Provider",
    "Callback",
    "Cache",
    "Path",
    "Value",
  }
  local labels = {}
  for index = 1, count do
    local n = index - 1
    local verb = verbs[n % #verbs + 1]
    local noun = nouns[math.floor(n / #verbs) % #nouns + 1]
    local suffix = suffixes[math.floor(n / (#verbs * #nouns)) % #suffixes + 1]
    local label = verb .. noun .. suffix
    if index % 7 == 0 then
      label = verb .. "_" .. noun:lower() .. "_" .. suffix:lower()
    elseif index % 31 == 0 then
      label = "变量" .. label
    end
    labels[index] = (dense and "completion" or label) .. string.format("_%05d", index)
  end
  return labels
end

---@param labels                        string[]
---@return table[]
function M.items(labels)
  local items = {}
  for index, label in ipairs(labels) do
    items[index] = { label = label, sortText = label, kind = 6, score_offset = 0, source_id = "bench" }
  end
  return items
end

---@param values                        number[]
---@return table
function M.stats(values)
  return {
    median = Stats.median(values),
    p95 = Stats.percentile(values, 0.95),
    min = Stats.percentile(values, 0),
    max = Stats.percentile(values, 1),
    samples = values,
  }
end

---@return number
function M.rss_kib()
  return vim.uv.resident_set_memory() / 1024
end

---@param functions                     table<string, fun(): any>
---@param samples                       integer
---@return table
function M.measure(functions, samples)
  local names = vim.tbl_keys(functions)
  table.sort(names)
  local values, outputs = {}, {}
  for _, name in ipairs(names) do
    values[name] = {}
  end
  for sample = 1, samples + 5 do
    collectgarbage("collect")
    for step = 1, #names do
      local name = names[(step + sample - 2) % #names + 1]
      local start = vim.uv.hrtime()
      outputs[name] = functions[name]()
      local elapsed = (vim.uv.hrtime() - start) / 1e6
      if sample > 5 then
        values[name][#values[name] + 1] = elapsed
      end
    end
  end
  local result = {}
  for _, name in ipairs(names) do
    result[name] = M.stats(values[name])
    result[name].count = type(outputs[name]) == "table" and #outputs[name] or nil
    result[name].bytes = type(outputs[name]) == "string" and #outputs[name] or nil
  end
  return result
end

return M
