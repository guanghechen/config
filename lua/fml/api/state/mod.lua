local constant = require("fml.constant")
local Observable = require("fml.collection.observable")
local AdvanceHistory = require("fml.collection.history_advance")
local fs = require("fml.std.fs")
local util = require("fml.std.util")

---@type table<string, boolean>
local BUF_IGNORED_FILETYPES = {
  ["PlenaryTestPopup"] = true,
  ["TelescopePrompt"] = true,
  ["Trouble"] = true,
  ["checkhealth"] = true,
  ["lspinfo"] = true,
  ["neo-tree"] = true,
  ["notify"] = true,
  ["startuptime"] = true,
  [constant.FT_TERM] = true,
}

---@class fml.api.state
---@field public bufs                   table<integer, fml.types.api.state.IBufItem>
---@field public tabs                   table<integer, fml.types.api.state.ITabItem>
---@field public tab_history            fml.types.collection.IAdvanceHistory
---@field public term_map               table<string, fml.types.api.state.ITerm>
---@field public wins                   table<integer, fml.types.api.state.IWinItem>
---@field public win_history            fml.types.collection.IAdvanceHistory
---@field public winline_dirty_nr       fml.types.collection.IObservable
local M = {}

---@param winnr                         number
---@return boolean
function M.is_floating_win(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
end

---@param filetype                      string
---@return boolean
function M.is_ignored_filetype(filetype)
  return not not BUF_IGNORED_FILETYPES[filetype]
end

---@param bufnr                         integer|nil
---@return boolean
function M.validate_buf(bufnr)
  if bufnr == nil or bufnr == 0 then
    return false
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  if vim.fn.buflisted(bufnr) ~= 1 then
    return false
  end

  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
  return not BUF_IGNORED_FILETYPES[filetype]
end

---@param filepath                      string|nil
---@return boolean
function M.validate_filepath(filepath)
  if filepath == nil or filepath == "" or filepath == constant.BUF_UNTITLED then
    return false
  end
  return fs.is_file_or_dir(filepath) == "file"
end

---@param tabnr                         integer|nil
---@return boolean
function M.validate_tab(tabnr)
  if tabnr == nil or tabnr == 0 then
    return false
  end

  if not vim.api.nvim_tabpage_is_valid(tabnr) then
    return false
  end
  return true
end

---@param winnr                         integer|nil
---@return boolean
function M.validate_win(winnr)
  if winnr == nil or winnr == 0 then
    return false
  end

  if not vim.api.nvim_win_is_valid(winnr) then
    return false
  end
  return not M.is_floating_win(winnr)
end

M.bufs = {}
M.tabs = {}
M.tab_history = AdvanceHistory.new({
  name = "tabs",
  capacity = constant.TAB_HISTORY_CAPACITY,
  validate = M.validate_tab,
})
M.term_map = {}
M.wins = {}
M.win_history = AdvanceHistory.new({
  name = "wins",
  capacity = constant.WIN_HISTORY_CAPACITY,
  validate = M.validate_win,
})
M.winline_dirty_nr = Observable.from_value(0, util.falsy)

return M
