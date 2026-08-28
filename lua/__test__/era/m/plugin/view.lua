---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/plugin/view.lua

local harness = require("__test__.harness")
require("ark.bootstrap").setup()

local View = require("era.m.plugin.view")
local Widget = require("era.m.plugin.widget")
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
  return {
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
  },
    calls
end

---@return era.m.plugin.View, fun(): integer
local function fake_view()
  local updates = 0 ---@type integer
  local view = setmetatable({
    widget = {
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

t:test("actions update the single view without changing UI mode", function()
  local action, calls = fake_action()
  t:patch_table(package.loaded, "era.m.plugin.action", action)
  local view, updates = fake_view()

  view:__run_action__("install")
  view:__run_action__("update")
  view:__run_action__("clean")

  t.assert_eq(1, calls.install, "install calls")
  t.assert_eq(1, calls.update, "update calls")
  t.assert_eq(1, calls.clean, "clean calls")
  t.assert_eq(3, calls.finally, "finally registrations")
  t.assert_eq(3, updates(), "view updates")
end)

t:test("actions are ignored while another operation is running", function()
  local action, calls = fake_action()
  action.is_running = function()
    return true
  end
  t:patch_table(package.loaded, "era.m.plugin.action", action)
  local view, updates = fake_view()

  view:__run_action__("update")

  t.assert_eq(0, calls.update, "update calls")
  t.assert_eq(0, updates(), "view updates")
end)

t:test("show refreshes an already visible view", function()
  local updates = 0 ---@type integer
  t:patch_table(Widget, "new", function()
    return {
      update = function()
        updates = updates + 1
      end,
    }
  end)
  t:_register_cleanup(function()
    View.close_view()
    vim.wait(10)
  end)

  View.show()
  t.assert_eq(1, updates, "initial render")

  View.show()
  t.assert_eq(2, updates, "visible refresh")
end)

t:run()
