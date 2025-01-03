local fs = require("eve.builtin.fs")
local fts = require("eve.constant.filetype")
local setting = require("eve.constant.setting")

---@class eve.lib.checks
local M = {}

---@param bufnr                         integer|nil
---@return boolean
function M.is_buf_valid(bufnr)
  if bufnr == nil or bufnr < 1 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if not vim.bo[bufnr].buflisted then
    return false
  end

  if not fts.is_plain_file(vim.bo[bufnr].filetype) then
    return false
  end

  return true
end

---@param tabnr                         integer|nil
---@return boolean
function M.is_tab_valid(tabnr)
  if tabnr == nil or tabnr < 1 or not vim.api.nvim_tabpage_is_valid(tabnr) then
    return false
  end

  return true
end

---@param winnr                         integer|nil
---@return boolean
function M.is_win_floating(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return false
  end
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer|nil
---@return boolean
function M.is_win_valid(winnr)
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return false
  end

  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  if config.relative ~= nil and config.relative ~= "" then
    return false
  end

  return true
end

---@param filepath                      string|nil
---@return boolean
function M.is_valid_filepath(filepath)
  if filepath == nil or filepath == "" or filepath == setting.BUF_UNTITLED then
    return false
  end
  return fs.is_file_or_dir(filepath) == "file"
end

return M
