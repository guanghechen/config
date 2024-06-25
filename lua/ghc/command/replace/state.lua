---@class ghc.command.replace.State
---@field private data                  ghc.types.command.replace.IStateData
---@field private search_result         fml.core.oxi.search.IResult|nil
---@field private dirty_search          boolean
---@field private dirty_replace         boolean
---@field private on_changed            fun(ghc.command.replace.State): nil
local M = {}
M.__index = M

---@param data ghc.types.command.replace.IStateData
---@return ghc.types.command.replace.IStateData
local function internal_normalize(data)
  local search_paths = fml.oxi.normalize_comma_list(data.search_paths) ---@type string
  local include_patterns = fml.oxi.normalize_comma_list(data.include_patterns) ---@type string
  local exclude_patterns = fml.oxi.normalize_comma_list(data.exclude_patterns) ---@type string

  ---@type ghc.types.command.replace.IStateData
  local normalized = {
    cwd = data.cwd,
    mode = data.mode,
    flag_case_sensitive = data.flag_case_sensitive,
    flag_regex = data.flag_regex,
    search_pattern = data.search_pattern,
    replace_pattern = data.replace_pattern,
    search_paths = search_paths,
    include_patterns = include_patterns,
    exclude_patterns = exclude_patterns,
  }
  return normalized
end

---@param left ghc.types.command.replace.IStateData
---@param right ghc.types.command.replace.IStateData
---@return boolean, boolean
local function internal_equals(left, right)
  local state_equals = left.cwd == right.cwd
    and left.flag_regex == right.flag_regex
    and left.flag_case_sensitive == right.flag_case_sensitive
    and left.search_pattern == right.search_pattern
    and left.search_paths == right.search_paths
    and left.include_patterns == right.include_patterns
    and left.exclude_patterns == right.exclude_patterns
  local replace_equals = state_equals and left.mode == right.mode and left.replace_pattern == right.replace_pattern
  return state_equals, replace_equals
end

---@class ghc.command.replace.state.IProps
---@field public initial_data           ghc.types.command.replace.IStateData
---@field public on_changed             fun(ghc.command.replace.State): nil

---@param props ghc.command.replace.state.IProps
---@return ghc.command.replace.State
function M.new(props)
  local self = setmetatable({}, M)

  self.data = internal_normalize(props.initial_data)
  self.search_result = nil
  self.dirty_search = true
  self.dirty_replace = true
  self.on_changed = props.on_changed

  return self
end

---@return ghc.types.command.replace.IStateData
function M:get_data()
  return vim.deepcopy(self.data)
end

---@param next_data ghc.types.command.replace.IStateData
function M:set_data(next_data)
  local normalized_next_data = internal_normalize(next_data) ---@type ghc.types.command.replace.IStateData
  local state_equals, replace_equals = internal_equals(self.data, normalized_next_data)
  self.dirty_search = not state_equals
  self.dirty_replace = not replace_equals

  if self.dirty_search or self.dirty_replace then
    self.data = normalized_next_data
    self.on_changed(self)
  end
end

---@param key ghc.enums.command.replace.StateKey
function M:get_value(key)
  return self.data[key]
end

---@param key ghc.enums.command.replace.StateKey
---@param val string|boolean|ghc.enums.command.replace.Mode|nil
function M:set_value(key, val)
  if val ~= nil and self.data[key] ~= val then
    self.data[key] = val
    if key ~= "mode" and key ~= "replace_pattern" then
      self.dirty_search = true
    end
    self.dirty_replace = true
    self.on_changed(self)
  end
end

---@param flag_name "flag_regex"|"flag_case_sensitive"
function M:toggle_flag(flag_name)
  local value = self.data[flag_name] ---@type boolean
  local next_value = not value ---@type boolean
  self:set_value(flag_name, next_value)
end

---@return boolean
function M:is_dirty_search()
  return self.dirty_search
end

---@return boolean
function M:is_dirty_replace()
  return self.dirty_replace
end

---@param force ?boolean
---@return fml.core.oxi.search.IResult|nil
function M:search(force)
  if force or self:is_dirty_search() then
    local data = self.data ---@type ghc.types.command.replace.IStateData

    ---@type fml.core.oxi.search.IParams
    local options = {
      cwd = data.cwd,
      flag_regex = data.flag_regex,
      flag_case_sensitive = data.flag_case_sensitive,
      search_pattern = data.search_pattern,
      search_paths = data.search_paths,
      include_patterns = data.include_patterns,
      exclude_patterns = data.exclude_patterns,
    }
    local result = fml.oxi.search(options)

    self.dirty = false
    self.search_result = result
  end
  return vim.deepcopy(self.search_result)
end

return M
