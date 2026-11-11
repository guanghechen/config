---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.nvimbar" ---@type string

-- Nvimbar globals, windows and bars outside the composed runtime, and a clock that drives the nvimbar queue.

local bootstrap = require("__test__.support.bootstrap")

---@class __test__.support.nvimbar.IBarProps
---@field public get_max_width          ?fun(): integer Twenty columns by default.
---@field public on_fulfilled           ?fun(result: string, last_result: string|nil): nil
---@field public draw_interval          ?integer

---@class __test__.support.nvimbar.IClock
---@field public now                    number Milliseconds.
---@field public timers                 integer
---@field public queue                  table The fresh queue module.
---@field public Component              era.m.nvimbar.Component
---@field public Nvimbar                era.m.nvimbar.Nvimbar
---@field public advance                fun(self: __test__.support.nvimbar.IClock, at: number, hold: boolean|nil): nil

local M = {}

---Declares the globals an nvimbar uses outside the composed runtime: `cwd` as the working directory, Normal mode, plain
---text and basenames. Reporter errors raise.
---@param t                             __test__.support.Harness
---@param cwd                           string
---@return nil
function M.with_runtime(t, cwd)
  bootstrap.with_runtime(t, {
    stl = {
      fn = { noop = function() end },
      nvim = { fn = {
        txt = function(text)
          return text
        end,
      } },
      reporter = {
        error = function(details)
          error(vim.inspect(details))
        end,
      },
    },
    dot = {
      path = {
        cwd = function()
          return cwd
        end,
      },
      theme = {
        hlgroup = {
          common = {
            resolve_mode = function()
              return "n", "NORMAL"
            end,
          },
        },
      },
    },
    yoz = { path = {
      basename = function(path)
        return path:match("[^/]*$")
      end,
    } },
  })
end

---Opens a float of 30 by 3 on a scratch buffer, both removed when the case ends.
---@param t                             __test__.support.Harness
---@return integer winnr
---@return integer bufnr
function M.window(t)
  local bufnr = t:buffer()
  return t:window(bufnr, { relative = "editor", row = 1, col = 1, width = 30, height = 3 }), bufnr
end

---Creates an always active bar of `Nvimbar`, the module or a clock's copy of it, for `winnr`, disposed when the case
---ends. It lays out twenty columns unless `props` says otherwise.
---@param t                             __test__.support.Harness
---@param Nvimbar                       era.m.nvimbar.Nvimbar
---@param winnr                         integer
---@param props                         ?__test__.support.nvimbar.IBarProps
---@return era.m.nvimbar.Nvimbar
function M.bar(t, Nvimbar, winnr, props)
  props = props or {}
  local bar = Nvimbar.new({
    name = "test",
    comp_sep = "",
    comp_sep_hlname = "Normal",
    comp_sep_hlname_active = "Normal",
    get_preset_context = function()
      return { winnr = winnr }
    end,
    get_max_width = props.get_max_width or function()
      return 20
    end,
    is_active = function()
      return true
    end,
    on_fulfilled = props.on_fulfilled or function() end,
    draw_interval = props.draw_interval,
  })
  t:defer(function()
    bar:dispose()
  end)
  return bar
end

---A clock the case moves: `vim.uv.hrtime` reads `now`, and the nvimbar timer and `vim.schedule` callbacks run only as
---`advance` moves it. Fresh copies of the queue, Component and Nvimbar modules run on it; the queue shuts down when the
---case ends. `advance(at, hold)` keeps the scheduled callbacks queued when `hold` is true.
---@param t                             __test__.support.Harness
---@return __test__.support.nvimbar.IClock
function M.clock(t)
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

  clock.queue = assert(loadfile("lua/era/m/nvimbar/queue.lua"))()
  t:defer(function()
    assert(shutdown)()
  end)
  t:patch_table(package.loaded, "era.m.nvimbar.queue", clock.queue)
  clock.Component = assert(loadfile("lua/era/m/nvimbar/component.lua"))()
  t:patch_table(package.loaded, "era.m.nvimbar.component", clock.Component)
  clock.Nvimbar = assert(loadfile("lua/era/m/nvimbar/nvimbar.lua"))()

  ---@param at                          number
  ---@param hold                        ?boolean
  ---@return nil
  function clock:advance(at, hold)
    assert(at >= self.now, "clock must be monotonic")
    self.now = at
    if due and due <= at then
      due = nil
      assert(dispatch)()
    end
    if hold then
      return
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
