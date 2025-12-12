local WINHIGHLIGHT = "NormalFloat:f_maximize_float_normal,FloatBorder:f_maximize_float_border"

---@class fml.action.toggle.maximize.float
local M = {}

---@param original                      era.state.maximized.IOriginalFloatWindow|nil
---@return boolean
local function restore(original)
  if original == nil then
    era.state.maximized.clear_original_float()
    return false
  end

  local winnr = original.winnr ---@type integer
  if winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    era.state.maximized.clear_original_float()
    return false
  end

  if not era.win.is_float(winnr) then
    era.state.maximized.clear_original_float()
    return false
  end

  local cfg = vim.deepcopy(original.wincfg) ---@type vim.api.keyset.win_config
  local ok = pcall(vim.api.nvim_win_set_config, winnr, cfg) ---@type boolean
  vim.wo[winnr].winblend = original.winblend or 0
  vim.wo[winnr].winhighlight = original.winhighlight or ""
  era.state.maximized.clear_original_float()
  return ok
end

---@param winnr                         integer
---@return nil
function M.maximize(winnr)
  local original = era.state.maximized.get_original_float() ---@type era.state.maximized.IOriginalFloatWindow|nil
  if original ~= nil then
    if original.winnr == winnr then
      restore(original)
      return
    end
    restore(original)
  end

  local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  local winblend = vim.wo[winnr].winblend or 0 ---@type integer
  local winhighlight = vim.wo[winnr].winhighlight or "" ---@type string

  era.state.maximized.set_original_float({
    winnr = winnr,
    winblend = winblend,
    winhighlight = winhighlight,
    wincfg = vim.deepcopy(wincfg),
  })

  local cfg = era.state.maximized.compute_float_maximized_wincfg(wincfg) ---@type vim.api.keyset.win_config
  local ok = pcall(vim.api.nvim_win_set_config, winnr, cfg) ---@type boolean
  if not ok then
    restore(era.state.maximized.get_original_float())
    return
  end

  vim.wo[winnr].winblend = era.context.theme.get_float_winblend()
  vim.wo[winnr].winhighlight = WINHIGHLIGHT
end

return M
