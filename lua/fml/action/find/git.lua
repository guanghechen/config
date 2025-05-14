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

  local workspace = eve.path.workspace() ---@type string
  local result = vim.fn.system("git diff HEAD --name-only") ---@type string
  local lines = eve.oxi.parse_lines(result) ---@type string[]

  local filepaths = {} ---@type string[]
  for _, line in ipairs(lines) do
    local absolute_filepath = eve.path.join(workspace, line) ---@type string
    filepaths[#filepaths + 1] = absolute_filepath
  end

  git_filepaths_dirty = false
  picker:reset_filepaths(eve.path.cwd(), filepaths, false)
end

local picker = eve.ux.FilePicker.new({
  name = "find-git-not-committed",
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

  on_close = function()
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
  refresh(picker, false)
  picker:focus()
end

return M
