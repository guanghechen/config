local state = require("fml.api.state")
local std_array = require("fml.std.array")
local fs = require("fml.std.fs")
local path = require("fml.std.path")
local reporter = require("fml.std.reporter")

---@class fml.api.buf
local M = {}

---@param tabnr                         integer
---@return table<integer, boolean>
function M.get_visible_bufnrs(tabnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  local bufnrs = {} ---@type table<integer, boolean>
  for _, winnr in ipairs(winnrs) do
    local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    bufnrs[bufnr] = true
  end
  return bufnrs
end

---@param bufnr                         integer
---@return boolean
function M.is_visible(bufnr)
  local winnrs = vim.api.nvim_tabpage_list_wins(0) ---@type integer[]
  return std_array.some(winnrs, function(winnr)
    local win_bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
    return win_bufnr == bufnr
  end)
end

---@param filepath                      string
---@return integer|nil
function M.locate_by_filepath(filepath)
  local target_filepath = vim.fn.fnamemodify(filepath, ":p") ---@type string
  for bufnr, buf in pairs(state.bufs) do
    if buf.filepath == target_filepath then
      return bufnr
    end
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bufname = vim.api.nvim_buf_get_name(bufnr)
      local buf_filepath = vim.fn.fnamemodify(bufname, ":p")
      if buf_filepath == target_filepath then
        state.schedule_refresh_bufs()
        return bufnr
      end
    end
  end
  return nil
end

---@return integer
function M.open_filepath(filepath)
  local bufnr = M.locate_by_filepath(filepath) ---@type integer|nil
  if bufnr == nil then
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    bufnr = vim.api.nvim_get_current_buf() ---@type integer
  end
  return bufnr
end

---@return nil
function M.toggle_pin_cur()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local buf = state.bufs[bufnr] ---@type fml.types.api.state.IBufItem|nil
  if buf ~= nil then
    local pinned = buf.pinned ---@type boolean
    buf.pinned = not pinned
    vim.cmd("redrawtabline")
  end
end

return M
