local nvim_tools = require("nvim_tools")
local util_json = require("guanghechen.util.json")

---@param data kyokuya.replace.IReplaceStateData
---@return kyokuya.replace.IReplaceStateData
local function internal_normalize(data)
  local search_paths = nvim_tools.normalize_comma_list(data.search_paths) ---@type string
  local include_patterns = nvim_tools.normalize_comma_list(data.include_patterns) ---@type string
  local exclude_patterns = nvim_tools.normalize_comma_list(data.exclude_patterns) ---@type string

  ---@type kyokuya.replace.IReplaceStateData
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

---@param left kyokuya.replace.IReplaceStateData
---@param right kyokuya.replace.IReplaceStateData
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

---@class kyokuya.replace.IReplaceStateOptions
---@field public initial_data kyokuya.replace.IReplaceStateData
---@field public on_changed   fun(): nil

---@class kyokuya.replace.ReplaceState
---@field private data          kyokuya.replace.IReplaceStateData
---@field private search_result kyokuya.replace.ISearchResult|nil
---@field private dirty_search  boolean
---@field private dirty_replace boolean
---@field private on_changed    fun(): nil
local M = {}
M.__index = M

---@param opts kyokuya.replace.IReplaceStateOptions
---@return kyokuya.replace.ReplaceState
function M.new(opts)
  local self = setmetatable({}, M)

  self.data = internal_normalize(opts.initial_data)
  self.search_result = nil
  self.dirty_search = true
  self.dirty_replace = true
  self.on_changed = opts.on_changed

  return self
end

---@return kyokuya.replace.IReplaceStateData
function M:get_data()
  return vim.deepcopy(self.data)
end

function M:set_data(next_data)
  local normalized_next_data = internal_normalize(next_data) ---@type kyokuya.replace.IReplaceStateData
  local state_equals, replace_equals = internal_equals(self.data, normalized_next_data)
  self.dirty_search = not state_equals
  self.dirty_replace = not replace_equals

  if self.dirty_search or self.dirty_replace then
    self.data = normalized_next_data
    self.on_changed()
  end
end

---@param key kyokuya.replace.IReplaceStateKey
function M:get_value(key)
  return self.data[key]
end

---@param key kyokuya.replace.IReplaceStateKey
---@param val string|boolean|kyokuya.replace.IReplaceMode
function M:set_value(key, val)
  if self.data[key] ~= val then
    self.data[key] = val
    if key ~= "mode" and key ~= "replace_pattern" then
      self.dirty_search = true
    end
    self.dirty_replace = true
    self.on_changed()
  end
end

function M:is_dirty_search()
  return self.dirty_search
end

function M:is_dirty_replace()
  return self.dirty_replace
end

---@param force ?boolean
---@return kyokuya.replace.ISearchResult|nil
function M:search(force)
  if force or self:is_dirty_search() then
    local data = self.data ---@type kyokuya.replace.IReplaceStateData

    ---@type kyokuya.replace.IOXISearchOptions
    local options = {
      cwd = data.cwd,
      flag_regex = data.flag_regex,
      flag_case_sensitive = data.flag_case_sensitive,
      search_pattern = data.search_pattern,
      search_paths = data.search_paths,
      include_patterns = data.include_patterns,
      exclude_patterns = data.exclude_patterns,
    }

    local options_stringified = util_json.stringify(options)
    local result_str = nvim_tools.search(options_stringified)
    local result = util_json.parse(result_str)

    self.dirty = false
    self.search_result = result
  end
  return vim.deepcopy(self.search_result)
end

function M:replace_preview(text, replace_pattern)
  local data = self.data ---@type kyokuya.replace.IReplaceStateData

  if not data.flag_regex then
    return replace_pattern
  end

  local final_search_pattern = data.search_pattern
  if not data.flag_case_sensitive then
    final_search_pattern = "(?i)" .. data.search_pattern
  end
  return nvim_tools.replace_text(text, final_search_pattern, replace_pattern)
end

return M
