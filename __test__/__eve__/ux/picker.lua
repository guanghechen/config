require("plenary.reload").reload_module("eve.ux.view.treeview")
require("plenary.reload").reload_module("eve.ux.view.filetree")
require("plenary.reload").reload_module("eve.ux.picker")
require("plenary.reload").reload_module("eve.ux.picker-file")

local finder_input = eve.std.Observable.from_value("")
local flag_foldempty = eve.std.Observable.from_value(true)
local flag_fuzzy = eve.std.Observable.from_value(false)
local flag_regex = eve.std.Observable.from_value(false)
local flag_sensitive = eve.std.Observable.from_value(true)
local flag_viewtype = eve.std.Observable.from_value("tree")
local flag_case = eve.std.Observable.from_value(1)

local picker = eve.ux.FilePicker.new({
  uuid = "__test__eve_ux_picker__",
  name = "find-files",
  permanent = false,
  title = "Find files",
  height = 0.80,
  width = 0.85,

  finder_input = finder_input,
  finder_multiline = false,

  flag_foldempty = flag_foldempty,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,
  flag_viewtype = flag_viewtype,
  flags_start_index = 0,
  flags_prepend = {
    {
      desc = "find-files: open settings",
      callback = eve.std.fn.noop,
      snapshot = function()
        return eve.icon.symbols.setting, "picker_flag_purple"
      end,
    },
  },
  flags_append = {
    {
      desc = "find-files: test case",
      callback = function()
        local kase = flag_case:snapshot() ---@type integer
        local next_kase = kase % 2 + 1 ---@type integer
        flag_case:next(next_kase)
      end,
      snapshot = function()
        local kase = flag_case:snapshot() ---@type integer
        return string.format("%d", kase), "picker_flag_orange"
      end,
    },
  },
})

eve.fn.observe({ flag_case }, function()
  picker:mark_result_flags_dirty()
end, true)

flag_case:subscribe(
  eve.std.Subscriber.new({
    on_next = function(kase)
      if kase == 1 then
        local cwd = eve.path.cwd() ---@type string
        local command = string.format("fd '.lua'") ---@type string
        local filepaths = vim.split(vim.trim(vim.fn.system(command)), "\n", { plain = true }) ---@type string[]
        picker:reset_filepaths(cwd, filepaths, false)
      end

      if kase == 2 then
        local cwd = eve.path.cwd() ---@type string
        local filepaths = {
          "__test__/__eve__/ux/picker.lua:50:7",
          "lua/eve/ux/picker-file.lua:136:11",
          "lua/eve/ux/picker-file.lua:645:11",
          "lua/fml/action/find/git.lua:65:9",
        }
        picker:reset_filepaths(cwd, filepaths, true)
      end

      picker:mark_result_dirty()
      picker:focus()
    end,
  }),
  false
)
