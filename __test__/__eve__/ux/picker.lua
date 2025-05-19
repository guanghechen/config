require("plenary.reload").reload_module("eve.ux.picker.composer")
require("plenary.reload").reload_module("eve.ux.picker.finder")
require("plenary.reload").reload_module("eve.ux.picker.result")
require("plenary.reload").reload_module("eve.ux.picker.preview")
require("plenary.reload").reload_module("eve.ux.picker-file")
require("plenary.reload").reload_module("eve.ux.view.treeview")
require("plenary.reload").reload_module("eve.ux.view.filetree")

local finder_input = std.Observable.from_value("")
local flag_foldempty = std.Observable.from_value(true)
local flag_fuzzy = std.Observable.from_value(false)
local flag_regex = std.Observable.from_value(false)
local flag_sensitive = std.Observable.from_value(true)
local flag_viewtype = std.Observable.from_value("tree")
local flag_case = std.Observable.from_value(3)

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
      callback = std.fn.noop,
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

std.fn.observe({ flag_case }, function()
  picker:mark_result_flags_dirty()
end, true)

flag_case:subscribe(
  std.Subscriber.new({
    on_next = function(kase)
      if kase == 1 then
        local cwd = std.path.cwd() ---@type string
        local command = string.format("fd '.lua'") ---@type string
        local filepaths = vim.split(vim.trim(vim.fn.system(command)), "\n", { plain = true }) ---@type string[]
        picker:reset_filepaths(cwd, filepaths, false)
      end

      if kase == 2 then
        local cwd = std.path.cwd() ---@type string
        local filepaths = {
          "__test__/__eve__/ux/picker.lua:50:7",
          "lua/eve/ux/picker-file.lua:136:11",
          "lua/eve/ux/picker-file.lua:645:11",
          "lua/fml/action/find/git.lua:65:9",
        }
        picker:reset_filepaths(cwd, filepaths, true)
      end

      if kase == 3 then
        local filepaths = {
          "/opt/me/a.txt",
          "/bin/usr/b.txt",
        }
        picker:reset_filepaths("/", filepaths, true)
      end

      picker:mark_result_dirty()
      picker:focus()
    end,
  }),
  false
)
