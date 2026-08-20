---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/plugin/view.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()
local View = require("era.m.plugin.view")

local t = harness.new("era.m.plugin.view")

---@return table, table
local function fake_action()
  local calls = { install = 0, update = 0, clean = 0, finally = 0 }
  local future = {
    finally = function(self)
      calls.finally = calls.finally + 1
      return self
    end,
  }
  local action = {
    is_running = function()
      return false
    end,
    install = function()
      calls.install = calls.install + 1
      return future
    end,
    update = function()
      calls.update = calls.update + 1
      return future
    end,
    clean = function()
      calls.clean = calls.clean + 1
      return future
    end,
  }
  return action, calls
end

---@param mode                          era.m.plugin.ViewModeEnum
---@return era.m.plugin.View, fun(): integer
local function fake_view(mode)
  local updates = 0 ---@type integer
  local view = setmetatable({
    state = { mode = "profile" },
    widget = {
      get_mode_at = function()
        return mode
      end,
      update = function()
        updates = updates + 1
      end,
    },
    winnr = 42,
  }, View) ---@type era.m.plugin.View
  return view, function()
    return updates
  end
end

t:test("mouse click selects a mode without running its action", function()
  local action, calls = fake_action()
  t:patch_table(package.loaded, "era.m.plugin.action", action)
  t:patch_table(vim.fn, "getmousepos", function()
    return { winid = 42, line = 2, column = 30 }
  end)

  for _, mode in ipairs({ "update", "clean" }) do
    local view, updates = fake_view(mode --[[@as era.m.plugin.ViewModeEnum]])
    view:__on_left_mouse__()

    t.assert_eq(mode, view.state.mode, mode .. " selected mode")
    t.assert_eq(1, updates(), mode .. " widget updates")
  end

  t.assert_eq(0, calls.update, "update action calls")
  t.assert_eq(0, calls.clean, "clean action calls")
end)

t:test("explicit mode action still performs the requested operation", function()
  local action, calls = fake_action()
  t:patch_table(package.loaded, "era.m.plugin.action", action)

  local view, updates = fake_view("profile")
  view:__run_mode_action__("update")

  t.assert_eq("update", view.state.mode, "selected mode")
  t.assert_eq(1, calls.update, "update action calls")
  t.assert_eq(1, calls.finally, "finally registrations")
  t.assert_eq(2, updates(), "widget updates")
end)

t:run()
