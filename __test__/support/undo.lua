---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.undo" ---@type string

local M = {}

-- Types the keys in Insert mode of a new buffer as typed keys, leaves Insert mode, then undoes until nothing is left.
---@param t                             __test__.support.Harness
---@param keys                          string
---@return string[][]                   The lines after typing and after each undo step.
function M.states(t, keys)
  local showmode = vim.o.showmode ---@type boolean
  vim.o.showmode = false
  -- Keys that arrive together are inserted in one go, before a map among them reads the line, unless an InsertCharPre
  -- autocmd needs every character. Completion has one in the configuration, so these keys go one by one as well.
  local autocmd = vim.api.nvim_create_autocmd("InsertCharPre", { callback = function() end }) ---@type integer
  local previous = vim.api.nvim_get_current_buf() ---@type integer
  local bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  t:defer(function()
    vim.o.showmode = showmode
    vim.api.nvim_del_autocmd(autocmd)
    vim.api.nvim_set_current_buf(previous)
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_feedkeys(vim.keycode("i" .. keys .. "<Esc>"), "tx", false)

  local states = { vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) } ---@type string[][]
  while true do
    local seq = vim.fn.undotree().seq_cur ---@type integer
    vim.cmd("silent! undo")
    if vim.fn.undotree().seq_cur == seq then
      return states
    end
    states[#states + 1] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
end

return M
