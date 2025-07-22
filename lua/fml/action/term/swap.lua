---@class fml.action.term.swap
local M = {}

---@param step                          integer|nil
---@return nil
function M.swap_left(step)
  local index_current, termuuid_current = eve.term.current() ---@type integer, string|nil
  if termuuid_current == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local N = eve.term.size() ---@type integer
  local index_next = std.fn.navigate_circular(index_current, -step, N) ---@type integer
  local termuuid_next = eve.term.at(index_next) ---@type string|nil

  if termuuid_next == nil or termuuid_next == termuuid_current then
    return
  end

  eve.term.put(index_current, termuuid_next)
  eve.term.put(index_next, termuuid_current)
  eve.status.dirtier_termline:mark_dirty()
end

---@param step                          integer|nil
---@return nil
function M.swap_right(step)
  local index_current, termuuid_current = eve.term.current() ---@type integer, string|nil
  if termuuid_current == nil then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local N = eve.term.size() ---@type integer
  local index_next = std.fn.navigate_circular(index_current, step, N) ---@type integer
  local termuuid_next = eve.term.at(index_next) ---@type string|nil

  if termuuid_next == nil or termuuid_next == termuuid_current then
    return
  end

  eve.term.put(index_current, termuuid_next)
  eve.term.put(index_next, termuuid_current)
  eve.status.dirtier_termline:mark_dirty()
end

return M
