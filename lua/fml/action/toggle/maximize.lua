---@class fml.action.toggle.maximize
local M = {}

---@type integer
local MAXIMIZED_ZINDEX = 2000

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

---@return integer
local function resolve_zindex()
  return MAXIMIZED_ZINDEX
end

---@return integer, integer
local function resolve_editor_size()
  local ui_list = vim.api.nvim_list_uis()
  local ui = ui_list[1]
  if ui ~= nil then
    return ui.width, ui.height
  end
  return vim.o.columns, vim.o.lines
end

---@return boolean
local function is_tabline_visible()
  local showtabline = vim.o.showtabline ---@type integer
  if showtabline == 2 then
    return true
  end
  if showtabline == 1 then
    local tab_count = vim.fn.tabpagenr("$") ---@type integer
    return tab_count > 1
  end
  return false
end

---@return boolean
local function is_statusline_visible()
  local laststatus = vim.o.laststatus ---@type integer
  if laststatus >= 2 then
    return true
  end
  if laststatus == 1 then
    local tabpage = vim.api.nvim_get_current_tabpage()
    local wins = vim.api.nvim_tabpage_list_wins(tabpage) ---@type integer[]
    return #wins > 1
  end
  return false
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

  local maximize_cfg = vim.deepcopy(wincfg) ---@type vim.api.keyset.win_config
  local editor_width, editor_height = resolve_editor_size() ---@type integer, integer
  local top_offset = is_tabline_visible() and 1 or 0 ---@type integer
  local bottom_offset = is_statusline_visible() and 1 or 0 ---@type integer
  local available_height = math.max(1, editor_height - top_offset - bottom_offset) ---@type integer
  maximize_cfg.relative = "editor"
  maximize_cfg.anchor = "NW"
  maximize_cfg.row = top_offset
  maximize_cfg.col = 0
  maximize_cfg.zindex = resolve_zindex()
  local fitted_width, fitted_height = eve.box.fit_editor(editor_width, available_height, maximize_cfg.border, {
    cols = editor_width,
    rows = available_height,
  }) ---@type integer, integer
  maximize_cfg.width = fitted_width
  maximize_cfg.height = fitted_height

  local ok = pcall(vim.api.nvim_win_set_config, winnr_command, maximize_cfg) ---@type boolean
  if not ok then
    restore_original(eve.state.maximized.get_original())
    return
  end
  vim.wo[winnr_command].winblend = 0
end

return M
