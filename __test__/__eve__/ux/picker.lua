require("plenary.reload").reload_module("eve.ux.picker")
require("plenary.reload").reload_module("eve.ux.picker-file")
require("plenary.reload").reload_module("eve.ux.view.treeview")

---@class __test__.ux.picker.ITreeNodeData
---@field public uuid                   string
---@field public filepath               string
---@field public filetype               string
---@field public basename               string

local finder_input = eve.std.Observable.from_value("eve/ux")
local flag_fuzzy = eve.std.Observable.from_value(false)
local flag_regex = eve.std.Observable.from_value(false)
local flag_sensitive = eve.std.Observable.from_value(true)

local picker = eve.ux.FilePicker.new({
  uuid = "__test__eve_ux_picker__",
  name = "find-files",
  permanent = false,
  title = "Find files",

  finder_input = finder_input,
  finder_multiline = false,

  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,
  flags_start_index = 0,
  flags_prepend = {
    {
      type = "enum",
      desc = "find-files: open settings",
      callback = eve.std.fn.noop,
      snapshot = function()
        return true, eve.icon.symbols.setting
      end,
    },
  },
})

eve.fn.observe({ finder_input }, function()
  picker:mark_result_dirty()
end, true)
eve.fn.observe({ flag_fuzzy, flag_regex, flag_sensitive }, function()
  picker:mark_result_flags_dirty()
end, true)

local command = string.format("fd '.lua'") ---@type string
local filepaths = vim.split(vim.trim(vim.fn.system(command)), "\n", { plain = true }) ---@type string[]
picker:reset_filepaths(filepaths)
picker:mark_result_dirty()

picker:focus()
