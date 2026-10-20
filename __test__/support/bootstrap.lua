---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.bootstrap" ---@type string

local M = {}

---@param left                          table
---@param right                         table
---@return table
local function merge(left, right)
  local result = {} ---@type table

  for key, value in pairs(left) do
    result[key] = value
  end

  for key, value in pairs(right) do
    if type(value) == "table" and type(result[key]) == "table" then
      result[key] = merge(result[key], value)
    else
      result[key] = value
    end
  end

  return result
end

---Replaces a global table with a copy of it merged with `spec`, restored when the case or suite ends.
---@param harness                       __test__.support.Harness
---@param name                          string
---@param spec                          table
---@return fun()
function M.with_global(harness, name, spec)
  local current = rawget(_G, name) ---@type table|nil
  return harness:patch_global(name, merge(type(current) == "table" and current or {}, spec))
end

---@param harness                       __test__.support.Harness
---@param spec                          table<string, table>
---@return (fun())[]
function M.with_runtime(harness, spec)
  local cleanups = {} ---@type (fun())[]
  for name, value in pairs(spec) do
    cleanups[#cleanups + 1] = M.with_global(harness, name, value)
  end
  return cleanups
end

---Exposes the native library this platform installs on the runtimepath (`lua/yoz.so`, or `lua/yoz.dll` on
---Windows) as `yoz`, with the `stl` pieces its Lua wrappers use. Reporter errors raise; warnings are dropped.
---@param harness                       __test__.support.Harness
---@return table
function M.with_native(harness)
  local native = require("yoz")
  harness:patch_global("yoz", native)
  M.with_global(harness, "stl", {
    c = { Future = require("stl.c.future") },
    nvim = { fn = require("stl.nvim.fn") },
    reporter = {
      warn = function() end,
      error = function(options)
        error(options.message, 2)
      end,
    },
  })
  return native
end

---Records every `stl.reporter` report by level, in order, until the case or suite ends.
---@param harness                       __test__.support.Harness
---@return table<"debug"|"info"|"warn"|"error", table[]>
function M.with_reporter(harness)
  if type(rawget(_G, "stl")) ~= "table" or type(stl.reporter) ~= "table" then
    M.with_global(harness, "stl", { reporter = {} })
  end
  local reports = { debug = {}, info = {}, warn = {}, error = {} } ---@type table<string, table[]>
  for level, list in pairs(reports) do
    harness:patch_table(stl.reporter, level, function(options)
      list[#list + 1] = options
    end)
  end
  return reports
end

return M
