local constants = require("eve.std.constants")
local std_array = require("eve.std.array")
local fs = require("eve.std.fs")

---@class eve.std.buf
local M = {}

---@type table<string, boolean>
local IGNORED_FILETYPES = {
  [constants.FT_CHECKHEALTH] = true,
  [constants.FT_DIFFVIEW_FILES] = true,
  [constants.FT_LSPINFO] = true,
  [constants.FT_NEOTREE] = true,
  [constants.FT_NOTIFY] = true,
  [constants.FT_PLENARY_TEST_POPUP] = true,
  [constants.FT_STARTUPTIME] = true,
  [constants.FT_TERM] = true,
  [constants.FT_TROUBLE] = true,
}

---@param bufnr                         integer
---@return boolean
function M.is_listed(bufnr)
  if vim.fn.buflisted(bufnr) ~= 1 then
    return false
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  return not IGNORED_FILETYPES[filetype]
end

---@param bufnr                         integer|nil
---@return boolean
function M.is_valid(bufnr)
  if bufnr == nil or bufnr == 0 then
    return false
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end
  return M.is_listed(bufnr)
end

---@param filepath                      string|nil
---@return boolean
function M.is_valid_filepath(filepath)
  if filepath == nil or filepath == "" or filepath == constants.BUF_UNTITLED then
    return false
  end
  return fs.is_file_or_dir(filepath) == "file"
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

return M
