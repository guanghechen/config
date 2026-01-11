local name = "era.fn.find_git" ---@type string
local title = "Find Git" ---@type string

local search_pattern_history = stl.c.InputHistory.new({ name = name, capacity = 5 })
local o_search_pattern = dot.context.select.find_git.search_pattern
local o_flag_foldempty = dot.context.select.find_git.flag_foldempty
local o_flag_fuzzy = dot.context.select.find_git.flag_fuzzy
local o_flag_regex = dot.context.select.find_git.flag_regex
local o_flag_case_sensitive = dot.context.select.find_git.flag_case_sensitive
local o_flag_selected = dot.context.select.find_git.flag_selected
local o_flag_viewtype = dot.context.select.find_git.flag_viewtype

local git_filepaths_dirty = true
local picker ---@type era.m.picker.FiletreeComposer

---@param force                         boolean
---@param callback                      fun()|nil
---@return nil
local function refresh(force, callback)
  if not force and not git_filepaths_dirty then
    if callback then
      callback()
    end
    return
  end

  era.m.git.state.status_async("HEAD", function(status)
    local workspace = dot.path.workspace()
    local filepaths = {} ---@type string[]
    for filepath in pairs(status) do
      filepaths[#filepaths + 1] = filepath
    end

    picker:reset_filepaths(workspace, filepaths, false)
    git_filepaths_dirty = false
    if callback then
      callback()
    end
  end)
end

picker = era.m.picker.FiletreeComposer.new({
  name = name,
  frecency = dot.context.frecency.files,
  permanent = true,
  title = string.format("%s (not committed)", title),
  height = 0.90,
  width = 120,
  preview = false,

  search_pattern = o_search_pattern,
  search_pattern_history = search_pattern_history,

  flag_foldempty = o_flag_foldempty,
  flag_fuzzy = o_flag_fuzzy,
  flag_regex = o_flag_regex,
  flag_case_sensitive = o_flag_case_sensitive,
  flag_selected = o_flag_selected,
  flag_viewtype = o_flag_viewtype,
  flags_start_index = 1,

  on_closed = function()
    git_filepaths_dirty = true
  end,
  on_focused = function()
    refresh(false, nil)
  end,
  on_refresh = function()
    era.m.git.state.refresh_async(true, function()
      refresh(true, nil)
    end)
  end,
})

---@return nil
local function find_git()
  if not dot.path.is_git_repo() then
    stl.reporter.error({
      from = name,
      subject = "find_git",
      message = "Not a git repository",
    })
    return
  end

  if picker:isfocused() then
    picker:hide()
    return
  end

  refresh(false, function()
    picker:focus()
  end)
end

return find_git
