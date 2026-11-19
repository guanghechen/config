require("ark.bootstrap").setup()
local picker = require("__test__.support.picker")
local t = require("__test__.support.harness").new()

---@param key                           stl.t.ToggleKeyEnum
---@return era.m.picker.result.IFlagItemRaw
local function flag(key)
  return {
    key = key,
    desc = key,
    callback = stl.fn.noop,
    snapshot = function()
      return key, "picker_flag_grey"
    end,
  }
end

t:test("a file picker numbers its flags from the shared table, around the flags it is given", function()
  local composer = picker.filetree(t, {
    name = "keys",
    permanent = false,
    preview = false,
    title = "keys",
    flags_prepend = { flag("t0") },
    flags_append = { flag("t7") },
  })
  local descs = {} ---@type table<string, string>
  for _, keymap in ipairs(composer.result.keymaps) do
    descs[keymap.key] = keymap.desc
  end
  t.assert_same({
    t0 = "keys: t0",
    t1 = "keys: selected only",
    t2 = "keys: viewtype",
    t3 = "keys: compact directory paths",
    t4 = "keys: fuzzy",
    t5 = "keys: sensitive",
    t6 = "keys: regex",
    t7 = "keys: t7",
  }, {
    t0 = descs.t0,
    t1 = descs.t1,
    t2 = descs.t2,
    t3 = descs.t3,
    t4 = descs.t4,
    t5 = descs.t5,
    t6 = descs.t6,
    t7 = descs.t7,
  })
  t.assert_eq("keys: fuzzy", descs["<C-4>"], "<C-4> toggles fuzzy as t4 does")
end)

t:run()
