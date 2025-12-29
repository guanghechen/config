local name = "era.fn.find_pinned_files" ---@type string
local title = "Find Pinned Files" ---@type string

local search_pattern = stl.c.Observable.from_value("")
local search_pattern_history = stl.c.InputHistory.new({
  name = name,
  capacity = 5,
  input = search_pattern,
})
local o_flag_foldempty = stl.c.Observable.from_value(true)
local o_flag_fuzzy = stl.c.Observable.from_value(false)
local o_flag_regex = stl.c.Observable.from_value(false)
local o_flag_case_sensitive = stl.c.Observable.from_value(true)
local o_flag_selected = stl.c.Observable.from_value(false)
local o_flag_viewtype = stl.c.Observable.from_value("tree")

---@param picker                        era.picker.FiletreeComposer
---@return nil
local function refresh(picker)
  local cwd = dot.path.cwd() ---@type string
  local filepaths = dot.context.bookmark.pinned:snapshot() ---@type string[]
  picker:reset_filepaths(cwd, filepaths, false)
end

local picker = era.picker.FiletreeComposer.new({
  name = name,
  frecency = dot.context.frecency.files,
  permanent = true,
  title = title,
  height = 0.9,
  width = 0.9,

  search_pattern = search_pattern,
  search_pattern_history = search_pattern_history,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,
  flag_selected = o_flag_selected,
  flag_viewtype = o_flag_viewtype,
  flags_start_index = 0,

  on_refresh = function(picker)
    refresh(picker)
  end,
})

stl.fn.observe({ dot.context.bookmark.pinned }, function()
  refresh(picker)
end, false)

---@return nil
local function find_pinned_files()
  picker:focus()
end

return find_pinned_files
