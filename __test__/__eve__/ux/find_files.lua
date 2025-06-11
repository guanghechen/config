require("plenary.reload").reload_module("std.collection.tree")
require("plenary.reload").reload_module("std.collection.filetree")
require("plenary.reload").reload_module("eve.ux.view.tree")
require("plenary.reload").reload_module("eve.ux.view.filetree")
require("plenary.reload").reload_module("eve.ux.picker.finder")
require("plenary.reload").reload_module("eve.ux.picker.result")
require("plenary.reload").reload_module("eve.ux.picker.preview")
require("plenary.reload").reload_module("eve.ux.picker.composer")
require("plenary.reload").reload_module("eve.ux.picker-file")

local name = "find-files" ---@type string
local last_scope_path = nil ---@type string|nil

local flag_exclude = eve.context.select.find_file.flag_exclude
local flag_foldempty = eve.context.select.find_file.flag_foldempty
local flag_fuzzy = eve.context.select.find_file.flag_fuzzy
local flag_gitignore = eve.context.select.find_file.flag_gitignore
local flag_regex = eve.context.select.find_file.flag_regex
local flag_sensitive = eve.context.select.find_file.flag_case_sensitive
local flag_selected = eve.context.select.find_file.flag_selected
local flag_viewtype = eve.context.select.find_file.flag_viewtype

local input = eve.context.select.find_file.input
local input_history = eve.context.select.find_file.input_history
local scope_path = std.Observable.from_value(std.path.cwd())

---@param picker                        eve.ux.FilePicker
---@return nil
local function refresh(picker)
  local workspace = std.path.workspace() ---@type string
  local p = scope_path:snapshot() ---@type string

  local enabled_exclude = flag_exclude:snapshot() ---@type boolean
  local enabled_gitignore = flag_gitignore:snapshot() ---@type boolean
  local excludes = enabled_exclude and eve.context.select.find_file.excludes:snapshot() or {} ---@type string[]

  ---@type string[]
  local filepaths = eve.oxi.find({
    workspace = workspace,
    cwd = p,
    flag_case_sensitive = false,
    flag_gitignore = enabled_gitignore,
    flag_regex = false,
    search_pattern = "",
    search_paths = "",
    exclude_patterns = table.concat(excludes, ","),
  })

  last_scope_path = p ---@type string
  picker:reset_filepaths(p, filepaths, false)
  picker:mark_result_dirty()
  picker:focus()
end

local picker = eve.ux.FilePicker.new({
  uuid = "__test__eve_ux_picker__",
  name = name,
  frecency = eve.context.frecency.files,
  permanent = false,
  title = "Find files",
  height = 0.80,
  width = 0.85,

  finder_input = input,
  finder_input_history = input_history,
  finder_multiline = false,

  flag_foldempty = flag_foldempty,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,
  flag_selected = flag_selected,
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
      desc = string.format("%s: toggle exclude", name),
      callback = function()
        local enabled = flag_exclude:snapshot() ---@type boolean
        flag_exclude:next(not enabled)
      end,
      snapshot = function()
        local enabled = flag_exclude:snapshot() ---@type boolean
        return eve.icon.symbols.flag_exclude, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
    {
      desc = string.format("%s: toggle gitignore", name),
      callback = function()
        local enabled = flag_gitignore:snapshot() ---@type boolean
        flag_gitignore:next(not enabled)
      end,
      snapshot = function()
        local enabled = flag_gitignore:snapshot() ---@type boolean
        return eve.icon.symbols.flag_gitignore, enabled and "picker_flag_blue" or "picker_flag_grey"
      end,
    },
  },

  on_refresh = function(self)
    refresh(self)
  end,
})

std.fn.observe({ scope_path }, function()
  local p = scope_path:snapshot() ---@type string
  local workspace = std.path.workspace() ---@type string
  local cwd = std.path.cwd() ---@type string
  if p == workspace then
    picker.finder:set_title("find files (workspace)")
  elseif p == cwd then
    picker.finder:set_title("find files (cwd)")
  else
    local relative_path = std.path.is_under(workspace, p) and std.path.relative(cwd, p, false) or p ---@type string
    picker.finder:set_title(string.format("find files (%s)", relative_path))
  end

  if last_scope_path == nil or not std.path.is_under(last_scope_path, p) then
    refresh(picker)
  end
end)

std.fn.observe({ flag_exclude, flag_gitignore }, function()
  refresh(picker)
end, false)
