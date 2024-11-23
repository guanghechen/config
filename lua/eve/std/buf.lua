local constants = require("eve.std.constants")
local std_array = require("eve.std.array")
local fs = require("eve.std.fs")
local ft = require("eve.std.filetype")

---@class eve.std.buf
local M = {}

---@param bufnr                         integer
---@return boolean
function M.is_listed(bufnr)
  if vim.fn.buflisted(bufnr) ~= 1 then
    return false
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  if not ft.is_plain_file(filetype) then
    return false
  end

  return true
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

---@param cwd                           string
---@param existed_filepaths             ?table<string, boolean>
---@return string|nil
function M.pick_filepath(cwd, existed_filepaths)
  if existed_filepaths == nil then
    existed_filepaths = {} ---@type table<string, boolean>

    local bufnrs = vim.api.nvim_list_bufs() ---@type integer[]
    for _, bufnr in ipairs(bufnrs) do
      local filename = vim.api.nvim_buf_get_name(bufnr) ---@type string
      local filepath = eve.path.resolve(cwd, filename) ---@type string
      existed_filepaths[filepath] = true
    end
  end

  for i = 1, 1000 do
    local filepath = eve.path.join(cwd, constants.BUF_UNTITLED .. "-" .. tostring(i)) ---@type string
    if not existed_filepaths[filepath] and vim.uv.fs_stat(filepath) == nil then
      return filepath
    end
  end
  return nil
end

return M
