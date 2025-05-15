local __module_name__ = "fml.action.find.git" ---@type string

---@class fml.action.find
local M = {}

local finder_input = eve.std.Observable.from_value("")
local flag_foldempty = eve.std.Observable.from_value(true)
local flag_fuzzy = eve.std.Observable.from_value(false)
local flag_regex = eve.std.Observable.from_value(false)
local flag_sensitive = eve.std.Observable.from_value(true)
local flag_viewtype = eve.std.Observable.from_value("tree")

local git_filepaths_dirty = true

---@param picker                        eve.ux.FilePicker
---@param force                         boolean
---@return nil
local function refresh(picker, force)
  if not force and not git_filepaths_dirty then
    return
  end

  local workspace, status = eve.viewmodel.git.status("HEAD") ---@type string, table<string, string>
  local filepaths = {} ---@type string[]
  for filepath in pairs(status) do
    filepaths[#filepaths + 1] = filepath
  end

  picker:reset_filepaths(workspace, filepaths, false)
  git_filepaths_dirty = false
end

local picker = eve.ux.FilePicker.new({
  name = "find-git-not-",
  permanent = true,
  title = "Find git (not committed)",
  height = 0.80,
  width = 0.50,
  preview = false,

  finder_input = finder_input,
  finder_multiline = false,

  flag_foldempty = flag_foldempty,
  flag_fuzzy = flag_fuzzy,
  flag_regex = flag_regex,
  flag_sensitive = flag_sensitive,
  flag_viewtype = flag_viewtype,
  flags_start_index = 1,

  on_closed = function()
    git_filepaths_dirty = true
  end,
  on_focused = function(picker)
    refresh(picker, false)
  end,
  on_refresh = function(picker)
    refresh(picker, true)
  end,
})

eve.fn.observe({ finder_input, flag_viewtype }, function()
  picker:mark_result_dirty()
end, true)
eve.fn.observe({ finder_input, flag_foldempty, flag_fuzzy, flag_regex, flag_sensitive, flag_viewtype }, function()
  picker:mark_result_flags_dirty()
end, true)

---@return nil
function M.find_git_not_committed()
  if not eve.path.is_repo_git() then
    eve.reporter.error({
      from = __module_name__,
      subject = "find_git_not_committed",
      message = "Not a git repository",
    })
    return
  end

  refresh(picker, false)
  picker:focus()
end

return M
