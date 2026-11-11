require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local Widget = require("era.m.git_files")

t:test("find-git owns one reusable dedicated widget and recreates it after disposal", function()
  local widgets = {}
  t:patch_table(Widget, "new", function()
    local widget = { toggles = 0, disposed = false }
    widget.isdisposed = function()
      return widget.disposed
    end
    widget.toggle = function()
      widget.toggles = widget.toggles + 1
    end
    widgets[#widgets + 1] = widget
    return widget
  end)
  local find = assert(loadfile("lua/era/fn/find-git.lua"))()
  find()
  find()
  t.assert_eq(1, #widgets)
  t.assert_eq(2, widgets[1].toggles)
  widgets[1].disposed = true
  find()
  t.assert_eq(2, #widgets)
end)

t:run()
