require("ark.bootstrap").setup()
local picker = require("__test__.support.picker")
local t = require("__test__.support.harness").new()

---@param key                           stl.t.ToggleKeyEnum
---@return era.m.searcher.result.IFlagItemRaw
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

t:test("file search numbers its flags from the shared table, with replace at t9 and tr", function()
  local composer = picker.searcher(t, {
    name = "keys",
    permanent = false,
    preview = false,
    title = "keys",
    rootpath = t:tempdir(),
    flags_prepend = { flag("t0") },
    flags_append = { flag("t7"), flag("t8"), flag("tl") },
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
    t5 = "keys: sensitive",
    t6 = "keys: regex",
    t7 = "keys: t7",
    t8 = "keys: t8",
    t9 = "keys: replace",
    tl = "keys: tl",
    tr = "searcher: toggle replace mode",
  }, {
    t0 = descs.t0,
    t1 = descs.t1,
    t2 = descs.t2,
    t3 = descs.t3,
    t5 = descs.t5,
    t6 = descs.t6,
    t7 = descs.t7,
    t8 = descs.t8,
    t9 = descs.t9,
    tl = descs.tl,
    tr = descs.tr,
  })
  t.assert_nil(descs.t4, "file search has no fuzzy flag")
  t.assert_eq("keys: replace", descs["<C-9>"], "<C-9> toggles replace as t9 does")
end)

t:run()
