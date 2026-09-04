local Scope = require("era.dressing.indentscope.scope")

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.indentscope.action" ---@type string

---@class era.dressing.indentscope.action
local M = {}

---@param side                          era.dressing.indentscope.Side
---@param use_border                    boolean
---@param scope                         era.dressing.indentscope.IScope
---@return nil
function M.move_cursor(side, use_border, scope)
  local target = use_border and scope.border[side] or nil ---@type integer|nil
  target = target or scope.body[side]
  target = math.min(math.max(target, 1), vim.api.nvim_buf_line_count(scope.bufnr))
  vim.api.nvim_win_set_cursor(scope.winnr, { target, 0 })
  vim.api.nvim_win_call(scope.winnr, function()
    vim.cmd("normal! ^")
  end)
end

---@param side                          era.dressing.indentscope.Side
---@param add_to_jumplist               boolean
---@param get_scope                     fun(line: integer|nil, col: integer|nil, options: era.dressing.indentscope.IOptionsOverride|nil): era.dressing.indentscope.IScope
---@return nil
function M.operator(side, add_to_jumplist, get_scope)
  local scope = get_scope(nil, nil, nil) ---@type era.dressing.indentscope.IScope
  if Scope.get_draw_col(scope) < 0 then
    return
  end

  local count = vim.v.count1 ---@type integer
  if add_to_jumplist then
    vim.cmd("normal! m`")
  end

  for index = 1, count do
    M.move_cursor(side, true, scope)
    if index < count then
      scope = get_scope(nil, nil, { try_as_border = false })
      if Scope.get_draw_col(scope) < 0 then
        return
      end
    end
  end
end

---@return nil
local function exit_visual_mode()
  local ctrl_v = vim.api.nvim_replace_termcodes("<C-v>", true, true, true) ---@type string
  local mode = vim.fn.mode() ---@type string
  if mode == "v" or mode == "V" or mode == ctrl_v then
    vim.cmd("normal! " .. mode)
  end
end

---@param use_border                    boolean
---@param get_scope                     fun(line: integer|nil, col: integer|nil, options: era.dressing.indentscope.IOptionsOverride|nil): era.dressing.indentscope.IScope
---@return nil
function M.textobject(use_border, get_scope)
  local scope = get_scope(nil, nil, nil) ---@type era.dressing.indentscope.IScope
  if Scope.get_draw_col(scope) < 0 then
    return
  end

  local count = use_border and vim.v.count1 or 1 ---@type integer
  for _ = 1, count do
    local first = "top" ---@type era.dressing.indentscope.Side
    local last = "bottom" ---@type era.dressing.indentscope.Side
    if use_border and scope.border.bottom == nil then
      first, last = last, first
    end

    local visual_mode = vim.fn.mode(1):match("^no(.)") or "V" ---@type string
    exit_visual_mode()
    M.move_cursor(first, use_border, scope)
    vim.cmd("normal! " .. visual_mode)
    M.move_cursor(last, use_border, scope)
    vim.cmd("normal! g_")

    scope = get_scope(nil, nil, { try_as_border = false })
    if Scope.get_draw_col(scope) < 0 then
      return
    end
  end
end

return M
