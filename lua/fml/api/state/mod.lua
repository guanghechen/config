---@class fml.api.state
---@field public bufs                   table<integer, fml.types.api.state.IBufItem>
---@field public tabs                   table<integer, fml.types.api.state.ITabItem>
---@field public tab_history            eve.types.collection.IAdvanceHistory
---@field public wins                   table<integer, fml.types.api.state.IWinItem>
---@field public winline_dirty_nr       eve.types.collection.IObservable
local M = {}

---@param winnr                         number
---@return boolean
function M.is_floating_win(winnr)
  local config = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  return config.relative ~= nil and config.relative ~= ""
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

  return eve.locations.is_listed_buf(bufnr)
end

---@param filepath                      string|nil
---@return boolean
function M.validate_filepath(filepath)
  if filepath == nil or filepath == "" or filepath == eve.constants.BUF_UNTITLED then
    return false
  end
  return eve.fs.is_file_or_dir(filepath) == "file"
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
M.tab_history = eve.c.AdvanceHistory.new({
  name = "tabs",
  capacity = eve.constants.TAB_HISTORY_CAPACITY,
  validate = M.validate_tab,
})
M.wins = {}
M.winline_dirty_nr = eve.c.Observable.from_value(0, eve.util.falsy)

return M
