require("plenary.reload").reload_module("std.collection.tree")
require("plenary.reload").reload_module("std.collection.filetree")
require("plenary.reload").reload_module("eve.ux.picker.composer.basic")
require("plenary.reload").reload_module("eve.ux.picker.composer.filetree")
require("plenary.reload").reload_module("eve.ux.picker.view.filetree")
require("plenary.reload").reload_module("eve.ux.picker.finder")
require("plenary.reload").reload_module("eve.ux.picker.preview")
require("plenary.reload").reload_module("eve.ux.picker.result")
require("plenary.reload").reload_module("eve.ux.retriever")
require("plenary.reload").reload_module("eve.ux.view.tree")

local name = "find-files" ---@type string
local finder_input = std.Observable.from_value("")
local finder_input_history = std.InputHistory.new({
  name = name,
  capacity = 5,
  input = finder_input,
})
local o_flag_foldempty = std.Observable.from_value(true)
local o_flag_fuzzy = std.Observable.from_value(false)
local o_flag_regex = std.Observable.from_value(false)
local o_flag_sensitive = std.Observable.from_value(true)
local o_flag_selected = std.Observable.from_value(false)
local o_flag_viewtype = std.Observable.from_value("tree")
local o_flag_case = std.Observable.from_value(2)

local picker = eve.ux.picker.FiletreeComposer.new({
  uuid = "__test__eve_ux_picker__",
  name = name,
  frecency = eve.context.frecency.files,
  permanent = false,
  title = "Find files",
  height = 0.80,
  width = 0.85,

  finder_input = finder_input,
  finder_input_history = finder_input_history,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
  flag_selected = o_flag_selected,
  flag_viewtype = o_flag_viewtype,
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
        local kase = o_flag_case:snapshot() ---@type integer
        local next_kase = kase % 3 + 1 ---@type integer
        o_flag_case:next(next_kase)
      end,
      snapshot = function()
        local kase = o_flag_case:snapshot() ---@type integer
        return string.format("%d", kase), "picker_flag_orange"
      end,
    },
  },
})

o_flag_case:subscribe(
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
          "/f/opt/me/a.txt",
          "/f/bin/usr/b.txt",
        }
        picker:reset_filepaths("/", filepaths, false)
      end

      picker:mark_result_dirty()
      picker:focus()
    end,
  }),
  false
)
