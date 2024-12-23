local constant = require("eve.lib.constant")
local ft = require("eve.lib.filetype")
local fs = require("eve.lib.fs")

---@type table<string, true>
local NON_TEXT_EXTNAME_SET = {
  [".class"] = true,
  [".dll"] = true,
  [".jpeg"] = true,
  [".jpg"] = true,
  [".gz"] = true,
  [".jar"] = true,
  [".mkv"] = true,
  [".mp3"] = true,
  [".mp4"] = true,
  [".pdf"] = true,
  [".png"] = true,
  [".so"] = true,
  [".tar"] = true,
  [".xz"] = true,
  [".zip"] = true,
}

---@type table<string, true>
local TEXT_FILENAME_SET = {
  ["license"] = true,
  ["sshd_config"] = true,
}

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

  if not ft.is_plain_file(vim.bo[bufnr].filetype) then
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

---@param value                         any
---@return boolean
function M.is_disposable(value)
  return type(value) == "table" and type(value.isDisposable) == "function" and type(value.dispose) == "function"
end

---@param value                         any
---@return boolean
function M.is_observable(value)
  return type(value) == "table"
    and type(value.snapshot) == "function"
    and type(value.next) == "function"
    and type(value.subscribe) == "function"
end

---@param filename                      string
---@return boolean
function M.is_printable_file(filename)
  filename = filename:lower() ---@type string
  local extname = filename:match("%.[^.]+$") or ""
  if NON_TEXT_EXTNAME_SET[extname] then
    return false
  end

  if extname == "" then
    return TEXT_FILENAME_SET[filename]
  end

  return true
end

---@param filepath                      string|nil
---@return boolean
function M.is_valid_filepath(filepath)
  if filepath == nil or filepath == "" or filepath == constant.BUF_UNTITLED then
    return false
  end
  return fs.is_file_or_dir(filepath) == "file"
end

return M
