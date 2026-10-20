---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.bench.cmp.child" ---@type string

local UI = require("__test__.support.ui")

---@class __test__.bench.cmp.IRecorder
---@field events                        { method: string, args: table, time: integer }[]

local M = {}

---Starts a child Neovim of this checkout with an attached 120x40 multigrid UI. The child's notifications, redraws
---included, are recorded with their arrival time; a runner clears `events` before each measured input.
---@return __test__.support.UI
---@return __test__.bench.cmp.IRecorder
function M.start()
  local ui = UI.new()
  local recorder = { events = {} } ---@type __test__.bench.cmp.IRecorder
  ---@param method                      string
  ---@param args                        table
  local function record(method, args)
    recorder.events[#recorder.events + 1] = { method = method, args = args, time = vim.uv.hrtime() }
  end
  ui.on_redraw = function(events)
    record("redraw", events)
  end
  ui.on_notification = record
  ui:start({ width = 120, height = 40, ui = { ext_multigrid = true } })
  return ui, recorder
end

return M
