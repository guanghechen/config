local name = "fml.action.find.pinned_files" ---@type string
local title = "Find Pinned Files" ---@type string

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

---@param picker                        eve.ux.picker.FiletreeComposer
---@return nil
local function refresh(picker)
  local cwd = std.path.cwd() ---@type string
  local filepaths = eve.context.bookmark.pinned:snapshot() ---@type string[]
  picker:reset_filepaths(cwd, filepaths, false)
end

local picker = eve.ux.picker.FiletreeComposer.new({
  name = name,
  frecency = eve.context.frecency.files,
  permanent = true,
  title = title,
  height = 0.9,
  width = 0.9,

  finder_input = finder_input,
  finder_input_history = finder_input_history,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_sensitive = o_flag_sensitive,
  flag_selected = o_flag_selected,
  flag_viewtype = o_flag_viewtype,
  flags_start_index = 0,

  on_refresh = function(picker)
    refresh(picker)
  end,
})

std.fn.observe({ eve.context.bookmark.pinned }, function()
  refresh(picker)
end, false)

---@class fml.action.find
local M = {}

---@return nil
function M.find_pinned_files()
  picker:focus()
end

return M
