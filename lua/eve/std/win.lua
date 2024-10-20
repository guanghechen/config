local fs = require("eve.std.fs")
local path = require("eve.std.path")

---@class eve.std.win.IDetails
---@field public winnr                  integer
---@field public bufnr                  integer
---@field public filepath               string|nil
---@field public dirpath                string|nil

---@class eve.std.win
local M = {}

---@param winnr                         integer|nil
---@return eve.std.win.IDetails|nil
function M.get_details(winnr)
  if winnr == nil or not M.is_valid(winnr) then
    return nil
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local filepath = vim.api.nvim_buf_get_name(bufnr) ---@type string
  local filetype = fs.is_file_or_dir(filepath) ---@type t.eve.e.FileType|nil
  if filetype == "file" or filetype == "directory" then
    local dirpath = filetype == "file" and path.dirname(filepath) or filepath ---@type string
    dirpath = path.normalize(dirpath)
    return { winnr = winnr, bufnr = bufnr, filepath = filepath, dirpath = dirpath }
  end
  return { winnr = winnr, bufnr = bufnr }
end

---@param winnr                         integer
---@return boolean
function M.is_floating(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param winnr                         integer|nil
---@return boolean
function M.is_valid(winnr)
  if winnr == nil or winnr == 0 then
    return false
  end

  if not vim.api.nvim_win_is_valid(winnr) then
    return false
  end
  return not M.is_floating(winnr)
end

return M
