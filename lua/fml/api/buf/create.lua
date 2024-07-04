local fs = require("fml.std.fs")
local state = require("fml.api.state")

---@class fml.api.buf
local M = require("fml.api.buf.mod")

---@return nil
function M.create()
  vim.cmd("new")

  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  state.refresh_tab(bufnr)

  local tab, tabnr = state.get_current_tab() ---@type fml.api.state.ITabItem|nil
  if tab == nil then
    return
  end

  table.insert(tab.bufnrs, bufnr)
  state.refresh_tab(tabnr)
end

---@param filepath                      string
---@return nil
function M.reload_or_load(filepath)
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  local target_bufnr = M.locate_by_filepath(filepath) ---@type integer|nil

  if target_bufnr ~= nil then
    local lines = vim.api.nvim_buf_get_lines(target_bufnr, 0, -1, false) ---@type string[]
    return table.concat(lines, "\n")
  end

  return fs.read_file({ filepath = target_filepath, silent = true }) or ""
end
