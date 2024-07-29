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
  local target_bufnr = M.locate_by_filepath(filepath) ---@type integer|nil

  if target_bufnr ~= nil then
    local lines = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false) ---@type string[]
    return table.concat(lines, "\n")
  end

  return fs.read_file({ filepath = target_filepath, silent = true }) or ""
end

---@param winnr                         integer
---@param filepath                      string
---@return nil
function M.open(winnr, filepath)
  filepath = vim.fn.fnameescape(filepath)
  if vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_set_current_win(winnr)
    vim.cmd("edit " .. filepath)
    vim.schedule(function()
      vim.cmd("stopinsert")
    end)
  end
end
