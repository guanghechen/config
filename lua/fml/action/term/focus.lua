---@class fml.action.term
local M = {}

---@param step                          integer|nil
---@return nil
function M.focus_left(step)
  local N = era.term.size() ---@type integer
  local termuuid = era.term.o_termuuid:snapshot() ---@type string
  local index_current = era.term.indexof(termuuid) ---@type integer
  if index_current < 0 then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = ark.fn.navigate_circular(index_current, -step, N) ---@type integer
  era.term.focus(index_next)
end

---@param step                          integer|nil
---@return nil
function M.focus_right(step)
  local N = era.term.size() ---@type integer
  local termuuid = era.term.o_termuuid:snapshot() ---@type string
  local index_current = era.term.indexof(termuuid) ---@type integer
  if index_current < 0 then
    return
  end

  step = math.max(1, step or vim.v.count1 or 1)
  local index_next = ark.fn.navigate_circular(index_current, step, N) ---@type integer
  era.term.focus(index_next)
end

return M
