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

---@param harness                       __test__.support.Harness
---@param spec                          table
---@return fun()
local function patch_global_table(harness, name, spec)
  local current = rawget(_G, name) ---@type table|nil
  local value = merge(type(current) == "table" and current or {}, spec)
  return harness:patch_global(name, value)
end

---@param harness                       __test__.support.Harness
---@param name                          string
---@param spec                          table
---@return fun()
function M.with_global(harness, name, spec)
  return patch_global_table(harness, name, spec)
end

---@param harness                       __test__.support.Harness
---@return fun()
function M.with_stl_c(harness)
  return M.with_global(harness, "stl", {
    c = {
      CancellationToken = require("stl.c.cancellation_token"),
      Future = require("stl.c.future"),
    },
  })
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

---@param harness                       __test__.support.Harness
---@param spec                          ?table
---@return fun()
function M.with_stl(harness, spec)
  if spec == nil then
    return M.with_stl_c(harness)
  end
  return patch_global_table(harness, "stl", spec)
end

---@param harness                       __test__.support.Harness
---@param spec                          table
---@return fun()
function M.with_dot(harness, spec)
  return patch_global_table(harness, "dot", spec)
end

---@param harness                       __test__.support.Harness
---@param spec                          table
---@return fun()
function M.with_era(harness, spec)
  return patch_global_table(harness, "era", spec)
end

---@param harness                       __test__.support.Harness
---@param spec                          table
---@return fun()
function M.with_yoz(harness, spec)
  return patch_global_table(harness, "yoz", spec)
end

return M
