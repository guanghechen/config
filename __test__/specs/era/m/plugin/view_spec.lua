--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/plugin/view_spec.lua
---@diagnostic disable: undefined-global

local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local View = require("era.m.plugin.view")
local Widget = require("era.m.plugin.widget")
local t = harness.new("era.m.plugin.view")

---@return table, table
local function fake_action()
  local calls = { install = 0, sync = 0, update = 0, clean = 0, finally = 0 }
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
    sync = function()
      calls.sync = calls.sync + 1
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
    __request_update__ = function(self)
      self.widget:update()
    end,
  }, View) ---@type era.m.plugin.View
  ---@diagnostic disable-next-line: return-type-mismatch
  return view, function()
    return updates
  end
end

t:test("actions update the single view without changing UI mode", function()
  local action, calls = fake_action()
  t:patch_table(package.loaded, "era.m.plugin.action", action)
  local view, updates = fake_view()

  view:__run_action__("install")
  view:__run_action__("sync")
  view:__run_action__("update")
  view:__run_action__("clean")

  t.assert_eq(1, calls.install, "install calls")
  t.assert_eq(1, calls.sync, "sync calls")
  t.assert_eq(1, calls.update, "update calls")
  t.assert_eq(1, calls.clean, "clean calls")
  t.assert_eq(4, calls.finally, "finally registrations")
  t.assert_eq(4, updates(), "view updates")
end)

t:test("progress updates are coalesced per event-loop tick", function()
  local scheduled = {} ---@type fun()[]
  local updates = 0
  t:patch_table(vim, "schedule", function(callback)
    scheduled[#scheduled + 1] = callback
  end)

  local view = setmetatable({
    _update_scheduled = false,
    widget = {
      update = function()
        updates = updates + 1
      end,
    },
    isvisible = function()
      return true
    end,
  }, View) ---@type era.m.plugin.View

  view:__request_update__()
  view:__request_update__()
  t.assert_eq(1, #scheduled, "scheduled updates")
  t.assert_eq(0, updates, "updates before flush")
  table.remove(scheduled, 1)()
  t.assert_eq(1, updates, "coalesced update")

  view:__request_update__()
  t.assert_eq(1, #scheduled, "next tick update")
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
  ---@diagnostic disable-next-line: invisible
  t:defer(function()
    View.close_view()
    vim.wait(10)
  end)

  View.show()
  t.assert_eq(1, updates, "initial render")
  t.assert_false(vim.api.nvim_get_option_value("wrap", { win = vim.api.nvim_get_current_win() }), "plugin view wrap")

  View.show()
  t.assert_eq(2, updates, "visible refresh")

  vim.api.nvim_exec_autocmds("User", { pattern = "DressingLoad", modeline = false, data = "notifier" })
  t.wait_until(function()
    return updates == 3
  end, 1000, "dressing load refreshes the visible view")
end)

t:run()
