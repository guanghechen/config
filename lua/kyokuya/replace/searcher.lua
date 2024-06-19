local util_json = require("guanghechen.util.json")
local util_table = require("guanghechen.util.table")

---@class kyokuya.replacer.Searcher : kyokuya.types.ISearcher
---@field private state kyokuya.types.ISearcherState|nil
---@field private result kyokuya.types.ISearchResult|nil
---@field private dirty boolean
local M = {}
M.__index = M

---@return kyokuya.types.ISearcher
function M.new()
  local self = setmetatable({}, M)

  self.state = nil
  self.result = nil
  self.dirty = true

  return self
end

---@param next_state kyokuya.types.ISearcherState|nil
---@return nil
function M:set_state(next_state)
  if next_state == nil then
    return
  end

  local normailized = self:normalize(next_state) ---@type kyokuya.types.ISearcherState
  if not self:equals(normailized) then
    self.dirty = true
    self.state = normailized
  end
end

---@param opts kyokuya.types.ISearcherOptions|nil
---@return kyokuya.types.ISearchResult|nil
function M:search(opts)
  local next_state = opts ~= nil and opts.state or nil ---@type kyokuya.types.ISearcherState|nil
  self:set_state(next_state)

  local force = opts and opts.force or false ---@type boolean
  local state = self.state ---@type kyokuya.types.ISearcherState|nil
  if state ~= nil and (self.dirty or force) then
    ---@type kyokuya.types.IOXISearchOptions
    local options = {
      cwd = state.cwd,
      flag_regex = state.flag_regex,
      flag_case_sensitive = state.flag_case_sensitive,
      search_pattern = state.search_pattern,
      search_paths = #state.search_paths > 0 and state.search_paths or { "" },
      include_patterns = #state.include_patterns > 0 and state.include_patterns or { "" },
      exclude_patterns = #state.exclude_patterns > 0 and state.exclude_patterns or { "" },
    }

    local nvim_tools = require("nvim_tools")
    local options_stringified = util_json.stringify(options)
    local result_str = nvim_tools.search(options_stringified)
    local result = util_json.parse(result_str)

    self.dirty = false
    self.result = result
  end

  return self.result
end

---@param text string
---@param replace_pattern string
---@return string
function M:replace_preview(text, replace_pattern)
  local state = self.state ---@type kyokuya.types.ISearcherState|nil
  if state == nil then
    return text
  end

  if not state.flag_regex then
    return replace_pattern
  end

  local final_search_pattern = state.search_pattern
  if not state.flag_case_sensitive then
    final_search_pattern = "(?i)" .. state.search_pattern
  end

  local nvim_tools = require("nvim_tools")
  return nvim_tools.replace_text(text, final_search_pattern, replace_pattern)
end

---@param state kyokuya.types.ISearcherState
---@return kyokuya.types.ISearcherState
function M:normalize(state)
  local search_paths = util_table.trim_and_filter(state.search_paths)
  local include_patterns = util_table.trim_and_filter(state.include_patterns)
  local exclude_patterns = util_table.trim_and_filter(state.exclude_patterns)

  ---@type kyokuya.types.ISearcherState
  local normalized = {
    cwd = state.cwd,
    flag_case_sensitive = state.flag_case_sensitive,
    flag_regex = state.flag_regex,
    search_pattern = state.search_pattern,
    search_paths = search_paths,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
  }
  return normalized
end

---@param next_state kyokuya.types.ISearcherState
---@return boolean
function M:equals(next_state)
  local state = self.state ---@type kyokuya.types.ISearcherState

  if state == nil then
    return false
  end

  if state == next_state then
    return true
  end

  return (
    state.cwd == next_state.cwd
    and state.flag_regex == next_state.flag_regex
    and state.flag_case_sensitive == next_state.flag_case_sensitive
    and state.search_pattern == next_state.search_pattern
    and util_table.equals_array(state.search_paths, next_state.search_paths)
    and util_table.equals_array(state.include_patterns, next_state.include_patterns)
    and util_table.equals_array(state.exclude_patterns, next_state.exclude_patterns)
  )
end

return M
