require("ark.bootstrap").setup()
local t = require("__test__.support.harness").new()
local picker = require("era.m.nvimbar.component.picker")

---@param key                           stl.t.ToggleKeyEnum
---@param icon                          string
---@param disabled                      ?boolean
---@return era.view.picker.result.IFlagItem
local function flag(key, icon, disabled)
  return {
    key = key,
    desc = icon,
    callback = "dot.G.noop",
    disabled = disabled and stl.fn.truthy or stl.fn.falsy,
    snapshot = function()
      return icon, "picker_flag_blue"
    end,
  }
end

t:test("result flags show numbered keys ascending, then lettered ones, each marked by its key", function()
  local flags = { flag("ts", "S"), flag("t9", "R"), flag("t1", "F"), flag("t7", "X", true) }
  t.assert_eq(" F¹ R⁹ Sˢ", picker.result_flags("f_wl", flags).refresh().text, "a disabled flag is left out")
end)

t:run()
