---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.fixtures.era.m.nvimbar.clock" ---@type string

---@class __test__.fixtures.nvimbar.IClock
---@field public now                    number
---@field public timers                 integer
---@field public Component              era.m.nvimbar.Component
---@field public Nvimbar                era.m.nvimbar.Nvimbar
---@field public advance                fun(self: __test__.fixtures.nvimbar.IClock, at: number): nil

local M = {}

---@param t                             __test__.support.Harness
---@return __test__.fixtures.nvimbar.IClock
function M.new(t)
  local clock = { now = 0, timers = 0 }
  local due = nil ---@type number|nil
  local dispatch = nil ---@type (fun(): nil)|nil
  local scheduled = {} ---@type (fun(): nil)[]
  local shutdown = nil ---@type (fun(): nil)|nil
  local create_autocmd = vim.api.nvim_create_autocmd

  t:patch_table(vim.uv, "hrtime", function()
    return clock.now * 1e6
  end)
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)
  t:patch_table(vim.uv, "new_timer", function()
    clock.timers = clock.timers + 1
    assert(clock.timers == 1, "nvimbar must keep one shared timer")
    return {
      unref = function() end,
      start = function(_, delay, _, callback)
        due, dispatch = clock.now + delay, callback
      end,
      stop = function()
        due = nil
      end,
      close = function()
        due = nil
      end,
    }
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, options)
    if event == "VimLeavePre" then
      shutdown = options.callback
      return 0
    end
    return create_autocmd(event, options)
  end)

  local queue = assert(loadfile("lua/era/m/nvimbar/queue.lua"))()
  t:defer(function()
    assert(shutdown)()
  end)
  t:patch_table(package.loaded, "era.m.nvimbar.queue", queue)
  clock.Component = assert(loadfile("lua/era/m/nvimbar/component.lua"))()
  t:patch_table(package.loaded, "era.m.nvimbar.component", clock.Component)
  clock.Nvimbar = assert(loadfile("lua/era/m/nvimbar/nvimbar.lua"))()

  ---@param at                          number
  ---@return nil
  function clock:advance(at)
    assert(at >= self.now, "clock must be monotonic")
    self.now = at
    if due and due <= at then
      due = nil
      assert(dispatch)()
    end
    local callbacks = scheduled
    scheduled = {}
    for _, callback in ipairs(callbacks) do
      callback()
    end
  end

  return clock
end

return M
