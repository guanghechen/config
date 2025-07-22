---@class fml.action.term
local M = {}

---@param step                          integer|nil
---@return nil
function M.focus_left(step)
  local N = eve.term.size() ---@type integer
  local termuuid = eve.term.o_termuuid:snapshot() ---@type string
  local index_current = eve.term.indexof(termuuid) ---@type integer
  if index_current < 0 then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = std.fn.navigate_circular(index_current, -step, N) ---@type integer
  eve.term.focus(index_next)
end

---@param step                          integer|nil
---@return nil
function M.focus_right(step)
  local N = eve.term.size() ---@type integer
  local termuuid = eve.term.o_termuuid:snapshot() ---@type string
  local index_current = eve.term.indexof(termuuid) ---@type integer
  if index_current < 0 then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = std.fn.navigate_circular(index_current, step, N) ---@type integer
  eve.term.focus(index_next)
end

return M
