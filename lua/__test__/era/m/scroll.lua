---@diagnostic disable: undefined-global
--- Test for era.m.scroll module
--- Run with: nvim -l lua/__test__/era/m/scroll.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.scroll")

---@param callback                     function
---@param name                         string
---@return any
local function get_upvalue(callback, name)
  local index = 1
  while true do
    local upvalue_name, value = debug.getupvalue(callback, index)
    if upvalue_name == nil then
      break
    end
    if upvalue_name == name then
      return value
    end
    index = index + 1
  end
  error("missing upvalue: " .. name)
end

---@class era.m.scroll.test.ITimer
---@field callback                     fun()|nil
---@field cleared                      boolean
local Timer = {}
Timer.__index = Timer

---@param _                             integer
---@param _                             integer
---@param callback                      fun()
---@return nil
function Timer:start(_, _, callback)
  self.callback = callback
end

---@class era.m.scroll.test.IRuntime
---@field autocmds                      table<string, table>
---@field bufnr                         integer
---@field valid                         boolean
---@field view                          vim.fn.winsaveview.ret
---@field options                       table<string, any>
---@field scheduled                     fun()[]
---@field timers                        era.m.scroll.test.ITimer[]
---@field observer                      fun()
---@field enabled                       boolean
---@field Scroll                        era.m.scroll
---@field check_scroll                  fun(winnr: integer)
---@field states                        table<integer, era.m.scroll.IState>
---@field get_states                    fun(): table<integer, era.m.scroll.IState>

---@return era.m.scroll.test.IRuntime
local function setup()
  local runtime = {
    autocmds = {},
    bufnr = 1,
    valid = true,
    view = { lnum = 1, col = 0, coladd = 0, curswant = 0, topline = 1, topfill = 0, leftcol = 0, skipcol = 0 },
    options = { virtualedit = "", scrolloff = 4 },
    scheduled = {},
    timers = {},
    enabled = true,
  } ---@type era.m.scroll.test.IRuntime

  t:patch_global("stl", {
    easing = {
      outQuad = function(_, _, _, _)
        return 0
      end,
    },
    fn = {
      observe = function(_, callback)
        runtime.observer = callback
        callback()
      end,
    },
    nvim = {
      fn = {
        augroup = function(name)
          return name
        end,
      },
    },
    timer = {
      clear_timer = function(timer)
        timer.cleared = true
      end,
    },
  })
  t:patch_global("dot", {
    context = {
      flight = {
        dressing_scroll = {
          snapshot = function()
            return runtime.enabled
          end,
        },
      },
    },
  })

  t:patch_table(vim, "schedule", function(callback)
    runtime.scheduled[#runtime.scheduled + 1] = callback
  end)
  t:patch_table(vim, "on_key", function(_, _)
    return 1
  end)
  t:patch_table(vim.uv, "new_timer", function()
    local timer = setmetatable({ callback = nil, cleared = false }, Timer)
    runtime.timers[#runtime.timers + 1] = timer
    return timer
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(event, opts)
    runtime.autocmds[type(event) == "string" and event or table.concat(event, ",")] = opts
    return 1
  end)
  t:patch_table(vim.api, "nvim_clear_autocmds", function() end)
  t:patch_table(vim.api, "nvim_list_wins", function()
    return { 1 }
  end)
  t:patch_table(vim.api, "nvim_win_is_valid", function()
    return runtime.valid
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return runtime.bufnr
  end)
  t:patch_table(vim.api, "nvim_buf_is_valid", function(bufnr)
    return bufnr == runtime.bufnr
  end)
  t:patch_table(vim.api, "nvim_buf_get_changedtick", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_current_win", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name)
    if name == "buftype" then
      return ""
    end
    if name == "scrollbind" then
      return false
    end
    return runtime.options[name]
  end)
  t:patch_table(vim.api, "nvim_set_option_value", function(name, value)
    runtime.options[name] = value
  end)
  t:patch_table(vim.api, "nvim_win_call", function(_, callback)
    return callback()
  end)
  t:patch_table(vim.api, "nvim_win_text_height", function(_, opts)
    return { all = opts.end_row - opts.start_row + 1 }
  end)
  t:patch_table(vim.fn, "winsaveview", function()
    return vim.deepcopy(runtime.view)
  end)
  t:patch_table(vim.fn, "winrestview", function(view)
    runtime.view = vim.deepcopy(view)
  end)
  t:patch_table(vim.fn, "winline", function()
    return runtime.view.lnum - runtime.view.topline + 1
  end)
  t:patch_table(vim.fn, "virtcol", function(pos)
    return pos[2] + 1
  end)

  runtime.Scroll = assert(loadfile("lua/era/m/scroll.lua"))()
  runtime.Scroll.dressing()

  local win_scrolled = runtime.autocmds.WinScrolled.callback ---@type function
  runtime.check_scroll = get_upvalue(win_scrolled, "check_scroll")
  local get_state = get_upvalue(runtime.check_scroll, "get_state") ---@type function
  runtime.states = get_upvalue(get_state, "states")
  runtime.get_states = function()
    return get_upvalue(get_state, "states")
  end
  return runtime
end

t:test("animates an unaccepted programmatic view change", function()
  local runtime = setup()

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  t.assert_eq(1, #runtime.timers, "animation timers")
  t.assert_true(runtime.states[1].timer == runtime.timers[1], "active animation timer")
end)

t:test("accepts a programmatic view change as the new baseline", function()
  local runtime = setup()

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.Scroll.accept_current_view(1)
  runtime.check_scroll(1)

  t.assert_eq(0, #runtime.timers, "animation timers")
  t.assert_eq(100, runtime.states[1].current.topline, "current topline")
  t.assert_eq(100, runtime.states[1].target.topline, "target topline")
  t.assert_eq(0, runtime.states[1].last, "repeat timestamp")
end)

t:test("cancels active animation and invalidates its queued callback", function()
  local runtime = setup()

  runtime.view.lnum = 100
  runtime.view.topline = 100
  runtime.check_scroll(1)

  local timer = runtime.timers[1]
  assert(timer.callback)()
  t.assert_eq(1, #runtime.scheduled, "queued timer callbacks")
  t.assert_eq("all", runtime.options.virtualedit, "animation virtualedit")
  t.assert_eq(0, runtime.options.scrolloff, "animation scrolloff")

  runtime.view.lnum = 50
  runtime.view.topline = 50
  runtime.Scroll.accept_current_view(1)

  t.assert_true(timer.cleared, "timer cleared")
  t.assert_nil(runtime.states[1].timer, "active timer")
  t.assert_eq("", runtime.options.virtualedit, "restored virtualedit")
  t.assert_eq(4, runtime.options.scrolloff, "restored scrolloff")
  t.assert_eq(50, runtime.states[1].current.topline, "accepted topline")

  table.remove(runtime.scheduled, 1)()
  t.assert_eq(50, runtime.view.topline, "view after stale callback")
end)

t:test("is a safe no-op while disabled", function()
  local runtime = setup()

  runtime.enabled = false
  runtime.observer()
  runtime.view.topline = 20
  runtime.Scroll.accept_current_view(1)

  t.assert_nil(runtime.get_states()[1], "window state")
  t.assert_eq(0, #runtime.timers, "animation timers")
end)

t:test("is a safe no-op for an invalid window", function()
  local runtime = setup()

  runtime.view.topline = 20
  runtime.valid = false
  runtime.Scroll.accept_current_view(1)

  t.assert_eq(1, runtime.states[1].current.topline, "current topline")
  t.assert_eq(0, #runtime.timers, "animation timers")
end)

t:test("replaces stale state when a window starts displaying another buffer", function()
  local runtime = setup()

  runtime.bufnr = 2
  runtime.view.lnum = 30
  runtime.view.topline = 30
  runtime.Scroll.accept_current_view(1)

  local state = runtime.get_states()[1]
  t.assert_eq(2, state.bufnr, "state buffer")
  t.assert_eq(30, state.current.topline, "current topline")
  t.assert_eq(0, #runtime.timers, "animation timers")
end)

t:run()
