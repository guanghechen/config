---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.bootstrap" ---@type string

---@class __test__.support.bootstrap.ISchedule
---@field callbacks                     fun()[] Queued callbacks, oldest first.
---@field drain                         fun(): nil Runs the queue in order, including callbacks queued meanwhile.

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

---Queues the callbacks `vim.schedule` receives, instead of running them, until the case or suite ends.
---@param harness                       __test__.support.Harness
---@return __test__.support.bootstrap.ISchedule
function M.with_schedule(harness)
  local schedule = { callbacks = {} } ---@type __test__.support.bootstrap.ISchedule
  harness:patch_table(vim, "schedule", function(callback)
    schedule.callbacks[#schedule.callbacks + 1] = callback
  end)
  function schedule.drain()
    while #schedule.callbacks > 0 do
      table.remove(schedule.callbacks, 1)()
    end
  end
  return schedule
end

---Records the callback of each autocommand created until the case or suite ends, by event, instead of creating it.
---@param harness                       __test__.support.Harness
---@return table<string, fun(args: table): any>
function M.with_autocmds(harness)
  local callbacks = {} ---@type table<string, fun(args: table): any>
  harness:patch_table(vim.api, "nvim_create_autocmd", function(events, opts)
    for _, event in ipairs(type(events) == "table" and events or { events }) do
      callbacks[event] = opts.callback
    end
    return 1
  end)
  return callbacks
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

---The message of each of `reports`, such as the reports of one level that `with_reporter` records, in order.
---@param reports                       { message: string }[]
---@return string[]
function M.messages(reports)
  return vim.tbl_map(function(report)
    return report.message
  end, reports)
end

return M
