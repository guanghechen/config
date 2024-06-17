local guanghechen = require("guanghechen")

---@class guanghechen.replace.Replacer : guanghechen.types.IReplacer
---@field private state guanghechen.types.IReplaceState|nil
---@field private result guanghechen.types.IReplaceResult|nil
---@field private dirty boolean
local Replacer = {}
Replacer.__index = Replacer

---@return guanghechen.replace.Replacer
function Replacer.new()
  local self = setmetatable({}, Replacer)

  self.state = nil
  self.result = nil
  self.dirty = true

  return self
end

---@param opts? {force?: boolean}
---@return guanghechen.types.IReplaceResult|nil
function Replacer:replace(opts)
  local force = opts and opts.force or false ---@type boolean
  local state = self.state ---@type guanghechen.types.IReplaceState|nil
  if state ~= nil and (self.dirty or force) then
    ---@type guanghechen.types.IReplaceOptions
    local options = {
      cwd = state.cwd,
      flag_regex = state.flag_regex,
      flag_case_sensitive = state.flag_case_sensitive,
      replace_pattern = state.replace_pattern,
      search_pattern = state.search_pattern,
      search_paths = #state.search_paths > 0 and state.search_paths or { "" },
      include_patterns = #state.include_patterns > 0 and state.include_patterns or { "" },
      exclude_patterns = #state.exclude_patterns > 0 and state.exclude_patterns or { "" },
    }

    local nvim_tools = require("nvim_tools")
    local options_stringified = guanghechen.util.json.stringify(options)
    local result_str = nvim_tools.replace(options_stringified)
    local result = guanghechen.util.json.parse(result_str)

    self.dirty = false
    self.result = result
  end

  return self.result
end

---@return guanghechen.types.IReplaceState
function Replacer:get_state()
  return self.state
end

---@param next_state guanghechen.types.IReplaceState|nil
---@return nil
function Replacer:set_state(next_state)
  if next_state ~= nil and not self:equals(next_state) then
    ---@type guanghechen.types.IReplaceState
    local state = {
      cwd = next_state.cwd,
      flag_regex = next_state.flag_regex,
      flag_case_sensitive = next_state.flag_case_sensitive,
      replace_pattern = next_state.replace_pattern,
      search_pattern = next_state.search_pattern,
      search_paths = guanghechen.util.table.slice(next_state.search_paths),
      include_patterns = guanghechen.util.table.slice(next_state.include_patterns),
      exclude_patterns = guanghechen.util.table.slice(next_state.exclude_patterns),
    }

    self.dirty = true
    self.state = state
  end
end

---@param next_state guanghechen.types.IReplaceState
---@return boolean
function Replacer:equals(next_state)
  local state = self.state ---@type guanghechen.types.IReplaceState

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
    or state.replace_pattern == next_state.replace_pattern
    or state.search_pattern == next_state.search_pattern
    or guanghechen.util.table.equals_array(state.search_paths, next_state.search_paths)
    or guanghechen.util.table.equals_array(state.include_patterns, next_state.include_patterns)
    or guanghechen.util.table.equals_array(state.exclude_patterns, next_state.exclude_patterns)
  )
end

return Replacer
