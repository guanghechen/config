---@diagnostic disable: undefined-global
--- Test for era.m.statuscolumn module
--- Run with: nvim -l lua/__test__/era/m/statuscolumn.lua

local harness = require("__test__.harness")

local t = harness.new("era.m.statuscolumn")

t:test("expires caches with a demand-driven one-shot timer", function()
  local timer = {
    active = false,
    callback = nil,
    starts = {},
  }
  local timer_count = 0
  local winnr = 1

  function timer:is_active()
    return self.active
  end

  function timer:start(timeout, repeat_interval, callback)
    self.active = true
    self.callback = callback
    self.starts[#self.starts + 1] = { timeout, repeat_interval }
  end

  t:patch_table(vim.uv, "new_timer", function()
    timer_count = timer_count + 1
    return timer
  end)
  t:patch_table(vim.api, "nvim_win_get_buf", function()
    return 1
  end)
  t:patch_table(vim.api, "nvim_get_option_value", function(name)
    if name == "signcolumn" then
      return "no"
    end
    if name == "foldcolumn" then
      return "0"
    end
    return false
  end)

  vim.g.statusline_winid = winnr
  local Statuscolumn = assert(loadfile("lua/era/m/statuscolumn.lua"))()

  Statuscolumn.statuscolumn()
  t.assert_eq(1, timer_count, "timer allocation count")
  t.assert_eq(1, #timer.starts, "initial timer start count")
  t.assert_eq(50, timer.starts[1][1], "expiration delay")
  t.assert_eq(0, timer.starts[1][2], "repeat interval")

  winnr = 2
  vim.g.statusline_winid = winnr
  Statuscolumn.statuscolumn()
  t.assert_eq(1, #timer.starts, "active timer remains scheduled once")

  timer.active = false
  assert(timer.callback)()
  Statuscolumn.statuscolumn()
  t.assert_eq(1, timer_count, "timer reuse count")
  t.assert_eq(2, #timer.starts, "timer restart count")
end)

t:run()
