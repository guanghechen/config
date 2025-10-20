---@class fml.action.toggle.maximize
local M = {}

---@param original                      eve.state.maximized.IOriginalWindow|nil
---@return boolean
local function restore_original(original)
  if original == nil then
    eve.state.maximized.clear_original()
    return false
  end

  local winnr = original.winnr ---@type integer
  if winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    eve.state.maximized.clear_original()
    return false
  end

  if not eve.win.is_float(winnr) then
    eve.state.maximized.clear_original()
    return false
  end

  local restore_cfg = vim.deepcopy(original.wincfg) ---@type vim.api.keyset.win_config
  local ok = pcall(vim.api.nvim_win_set_config, winnr, restore_cfg) ---@type boolean
  vim.wo[winnr].winblend = original.winblend or 0
  eve.state.maximized.clear_original()
  return ok
end

---@return nil
function M.maximize()
  local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
  if winnr_command == nil or winnr_command < 1 or not vim.api.nvim_win_is_valid(winnr_command) then
    return
  end

  if not eve.win.is_float(winnr_command) then
    return
  end

  local context_original = eve.state.maximized.get_original() ---@type eve.state.maximized.IOriginalWindow|nil
  if context_original ~= nil then
    if context_original.winnr == winnr_command then
      restore_original(context_original)
      return
    else
      restore_original(context_original)
    end
  end

  local wincfg = vim.api.nvim_win_get_config(winnr_command) ---@type vim.api.keyset.win_config
  local winblend = vim.wo[winnr_command].winblend or 0 ---@type integer

  eve.state.maximized.set_original({
    winnr = winnr_command,
    winblend = winblend,
    wincfg = vim.deepcopy(wincfg),
  })

  local maximize_cfg = eve.state.maximized.compute_maximized_wincfg(wincfg) ---@type vim.api.keyset.win_config

  local ok = pcall(vim.api.nvim_win_set_config, winnr_command, maximize_cfg) ---@type boolean
  if not ok then
    restore_original(eve.state.maximized.get_original())
    return
  end
  vim.wo[winnr_command].winblend = 0
end

return M
