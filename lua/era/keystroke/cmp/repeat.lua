-- The scratch-completion technique is adapted from blink.cmp (MIT).
-- Copyright (c) 2024 Liam Dyer. See LICENSE.blink in this directory.

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.repeat" ---@type string

local M = {}
local scratch_bufnr

---@param context                       era.keystroke.cmp.IContext
---@param plan                          era.keystroke.cmp.IEditPlan
---@param native_line                   string
---@param native_col                    integer
---@return nil
function M.record(context, plan, native_line, native_col)
  if vim.api.nvim_get_mode().mode:sub(1, 1) ~= "i" then
    return
  end
  local range = plan.main.range
  -- Typed input and native preview are already recorded; only the remaining edit belongs here.
  local deleted = native_line:sub(range.start.character + 1, range["end"].character + native_col - context.col)
  local eventignore = vim.o.eventignore
  local winnr
  vim.o.eventignore = "all"
  local ok, err = xpcall(function()
    if scratch_bufnr == nil or not vim.api.nvim_buf_is_valid(scratch_bufnr) then
      scratch_bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_option_value("filetype", "cmp-repeat", { buf = scratch_bufnr })
      -- An empty local option inherits global noselect. One item with "menu" inserts without opening a PUM.
      vim.api.nvim_set_option_value("completeopt", "menu", { buf = scratch_bufnr })
    end
    vim.api.nvim_buf_set_lines(scratch_bufnr, 0, -1, false, { "_" .. deleted })
    winnr = vim.api.nvim_open_win(
      scratch_bufnr,
      true,
      { relative = "editor", row = 0, col = 0, width = 1, height = 1, noautocmd = true, style = "minimal" }
    )
    vim.api.nvim_win_set_cursor(winnr, { 1, #deleted + 1 })
    -- Keep actual UTF-8 input: dummy bytes would record too many deletions for CJK text.
    vim.fn.complete(1, { "_" .. (plan.snippet and "" or plan.main.newText) })
  end, debug.traceback)
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
  if vim.api.nvim_win_is_valid(context.winnr) then
    vim.api.nvim_set_current_win(context.winnr)
  end
  vim.o.eventignore = eventignore
  if not ok then
    error(err, 0)
  end
  vim.fn.complete(vim.api.nvim_win_get_cursor(context.winnr)[2] + 1, {})
end

---@param amount                        integer
---@return nil
function M.move(amount)
  if amount == 0 then
    return
  end
  local key = amount > 0 and "<Right>" or "<Left>"
  local keys = ("<C-g>U" .. key):rep(math.abs(amount))
  vim.api.nvim_feedkeys(vim.keycode(keys), "in", false)
end

return M
