local util_json = require("guanghechen.util.json")
local util_table = require("guanghechen.util.table")

---@class guanghechen.util.searcher : guanghechen.types.ISearcher
---@field private state guanghechen.types.ISearcherState|nil
---@field private result guanghechen.types.ISearchResult|nil
---@field private dirty boolean
local Searcher = {}
Searcher.__index = Searcher

---@return guanghechen.types.ISearcher
function Searcher.new()
  local self = setmetatable({}, Searcher)

  self.state = nil
  self.result = nil
  self.dirty = true

  return self
end

---@return guanghechen.types.ISearcherState|nil
function Searcher:get_state()
  return self.state
end

---@param next_state guanghechen.types.ISearcherState|nil
---@return nil
function Searcher:set_state(next_state)
  if next_state ~= nil and not self:equals(next_state) then
    ---@type guanghechen.types.ISearcherState
    local state = {
      cwd = next_state.cwd,
      flag_regex = next_state.flag_regex,
      flag_case_sensitive = next_state.flag_case_sensitive,
      search_pattern = next_state.search_pattern,
      search_paths = util_table.slice(next_state.search_paths),
      include_patterns = util_table.slice(next_state.include_patterns),
      exclude_patterns = util_table.slice(next_state.exclude_patterns),
    }

    self.dirty = true
    self.state = state
  end
end

---@param opts? guanghechen.types.ISearcherOptions|nil
---@return guanghechen.types.ISearchResult|nil
function Searcher:search(opts)
  local next_state = opts ~= nil and opts.state or nil ---@type guanghechen.types.ISearcherState|nil
  self:set_state(next_state)

  local force = opts and opts.force or false ---@type boolean
  local state = self.state ---@type guanghechen.types.ISearcherState|nil
  if state ~= nil and (self.dirty or force) then
    ---@type guanghechen.types.IOXISearchOptions
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
function Searcher:replace_preview(text, replace_pattern)
  local state = self.state ---@type guanghechen.types.ISearcherState|nil
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

---@param next_state guanghechen.types.ISearcherState
---@return boolean
function Searcher:equals(next_state)
  local state = self.state ---@type guanghechen.types.ISearcherState

  if state == nil then
    return false
  end

  if state == next_state then
    return true
  end

  return (
    state.cwd == next_state.cwd
    or state.flag_regex == next_state.flag_regex
    or state.flag_case_sensitive == next_state.flag_case_sensitive
    or state.search_pattern == next_state.search_pattern
    or util_table.equals_array(state.search_paths, next_state.search_paths)
    or util_table.equals_array(state.include_patterns, next_state.include_patterns)
    or util_table.equals_array(state.exclude_patterns, next_state.exclude_patterns)
  )
end

return Searcher
