local state = require("fml.api.state")
local fs = require("fml.std.fs")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@return nil
function M.create()
  vim.cmd("new")
end

---@param filepath                      string
---@return string
function M.reload_or_load(filepath)
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  local target_bufnr = state.locate_bufnr_by_filepath(filepath) ---@type integer|nil

  if target_bufnr ~= nil then
    local lines = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false) ---@type string[]
    return table.concat(lines, "\n")
  end

  return fs.read_file({ filepath = target_filepath, silent = true }) or ""
end

---@param winnr                         integer
---@param filepath                      string
---@return boolean
function M.open(winnr, filepath)
  if vim.api.nvim_win_is_valid(winnr) then
    local bufnr = state.locate_bufnr_by_filepath(filepath) ---@type integer|nil
    if bufnr ~= nil then
      vim.api.nvim_win_set_buf(winnr, bufnr)
      return true
    end

    local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
    if winnr_cur == winnr then
      vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    else
      vim.api.nvim_set_current_win(winnr)
      vim.cmd("edit " .. vim.fn.fnameescape(filepath))
      vim.api.nvim_set_current_win(winnr_cur)
    end

    vim.schedule(function()
      vim.cmd("stopinsert")
    end)

    return true
  end
  return false
end

---@param filepath                      string
---@return boolean
function M.open_in_current_valid_win(filepath)
  local winnr = state.win_history:present() ---@type integer
  return M.open(winnr, filepath)
end
