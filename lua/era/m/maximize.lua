---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.maximize" ---@type string

local WINHIGHLIGHT_FLOAT = "NormalFloat:f_maximize_float_normal,FloatBorder:f_maximize_float_border"

---@class era.m.maximize
local M = {}

----------------------------------------------------------------------------------------------------
-- Float window maximize
----------------------------------------------------------------------------------------------------

---@param original                      dot.state.maximized.IOriginalFloatWindow|nil
---@return boolean
local function restore_float(original)
  if original == nil then
    dot.state.maximized.clear_original_float()
    return false
  end

  local winnr = original.winnr ---@type integer
  if winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    dot.state.maximized.clear_original_float()
    return false
  end

  if not stl.nvim.win.is_float(winnr) then
    dot.state.maximized.clear_original_float()
    return false
  end

  local cfg = vim.deepcopy(original.wincfg) ---@type vim.api.keyset.win_config
  local ok = pcall(vim.api.nvim_win_set_config, winnr, cfg) ---@type boolean
  vim.api.nvim_set_option_value("winblend", original.winblend or 0, { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", original.winhighlight or "", { win = winnr, scope = "local" })
  dot.state.maximized.clear_original_float()
  return ok
end

---@param winnr                         integer
---@return nil
local function maximize_float(winnr)
  local original = dot.state.maximized.get_original_float() ---@type dot.state.maximized.IOriginalFloatWindow|nil
  if original ~= nil then
    if original.winnr == winnr then
      restore_float(original)
      return
    end
    restore_float(original)
  end

  local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config
  local winblend = vim.api.nvim_get_option_value("winblend", { win = winnr }) or 0 ---@type integer
  local winhighlight = vim.api.nvim_get_option_value("winhighlight", { win = winnr }) or "" ---@type string

  dot.state.maximized.set_original_float({
    winnr = winnr,
    winblend = winblend,
    winhighlight = winhighlight,
    wincfg = vim.deepcopy(wincfg),
  })

  local cfg = dot.state.maximized.compute_float_maximized_wincfg(wincfg) ---@type vim.api.keyset.win_config
  local ok = pcall(vim.api.nvim_win_set_config, winnr, cfg) ---@type boolean
  if not ok then
    restore_float(dot.state.maximized.get_original_float())
    return
  end

  vim.api.nvim_set_option_value("winblend", dot.context.theme.get_float_winblend(), { win = winnr, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", WINHIGHLIGHT_FLOAT, { win = winnr, scope = "local" })
end

----------------------------------------------------------------------------------------------------
-- Normal window maximize
----------------------------------------------------------------------------------------------------

---@param normal                        dot.state.maximized.INormalContext
---@return nil
local function dispose_normal(normal)
  if dot.state.maximized.dispose_normal(normal) then
    dot.state.status.dirtier_tabline:mark_dirty()
  end
end

---@param tabnr                         integer
---@return boolean
local function close_tab(tabnr)
  if not vim.api.nvim_tabpage_is_valid(tabnr) then
    return true
  end
  if #vim.api.nvim_list_tabpages() <= 1 then
    return false
  end

  local tabid = vim.api.nvim_tabpage_get_number(tabnr) ---@type integer
  local ok, err = pcall(vim.api.nvim_cmd, { cmd = "tabclose", args = { tostring(tabid) } }, {})
  local closed = not vim.api.nvim_tabpage_is_valid(tabnr) ---@type boolean
  if not ok then
    stl.reporter.warn({
      from = __module_name__,
      subject = "close_normal",
      message = closed and "Maximize tab closed with errors" or "Failed to close maximize tab",
      details = { error = tostring(err) },
    })
  elseif not closed then
    stl.reporter.warn({
      from = __module_name__,
      subject = "close_normal",
      message = "Failed to close maximize tab",
    })
  end
  return closed
end

local close_normal ---@type fun(return_to_source: boolean): boolean

---@param normal                        dot.state.maximized.INormalContext
---@return nil
local function on_normal_tab_leave(normal)
  if
    dot.state.maximized.get_normal() ~= normal
    or normal.closing
    or vim.api.nvim_get_current_tabpage() ~= normal.maximize_tabnr
  then
    return
  end

  dot.state.maximized.sync_normal(normal)
  vim.schedule(function()
    if dot.state.maximized.get_normal() ~= normal or normal.closing then
      return
    end

    if not vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr) then
      dispose_normal(normal)
      return
    end

    if vim.api.nvim_get_current_tabpage() == normal.maximize_tabnr then
      close_normal(true)
      return
    end

    normal.closing = true
    if close_tab(normal.maximize_tabnr) then
      dispose_normal(normal)
    else
      normal.closing = false
    end
  end)
end

---@param return_to_source              boolean
---@return boolean
close_normal = function(return_to_source)
  local normal = dot.state.maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
  if normal == nil then
    return false
  end

  normal.closing = true
  dot.state.maximized.sync_normal(normal)

  if return_to_source and vim.api.nvim_tabpage_is_valid(normal.source_tabnr) then
    vim.api.nvim_set_current_tabpage(normal.source_tabnr)
    if vim.api.nvim_win_is_valid(normal.source_winnr) then
      vim.api.nvim_set_current_win(normal.source_winnr)
    end
  end

  if vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr) and #vim.api.nvim_list_tabpages() == 1 then
    vim.t[normal.maximize_tabnr].tabtype = stl.e.TabTypeEnum.NORMAL
    dot.tab.resolve(normal.maximize_tabnr, true)
    dispose_normal(normal)
    return true
  end

  if close_tab(normal.maximize_tabnr) then
    dispose_normal(normal)
    return true
  end

  normal.closing = false
  if vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr) then
    vim.api.nvim_set_current_tabpage(normal.maximize_tabnr)
  end
  return false
end

---@param winnr                         integer
---@return nil
local function maximize_normal(winnr)
  local normal = dot.state.maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
  if normal ~= nil then
    if vim.api.nvim_get_current_tabpage() == normal.maximize_tabnr then
      close_normal(true)
      return
    end
    if not close_normal(false) then
      return
    end
  end

  local source_tabnr = vim.api.nvim_win_get_tabpage(winnr) ---@type integer
  if source_tabnr ~= vim.api.nvim_get_current_tabpage() then
    return
  end
  if vim.api.nvim_get_current_win() ~= winnr then
    vim.api.nvim_set_current_win(winnr)
  end

  vim.cmd("tab split")
  local maximize_tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local maximize_winnr = vim.api.nvim_get_current_win() ---@type integer
  dot.win.fork(winnr, maximize_winnr)
  vim.t[maximize_tabnr].tabtype = stl.e.TabTypeEnum.MAXIMIZE

  local augroup = vim.api.nvim_create_augroup("era_maximize_normal", { clear = true }) ---@type integer
  normal = {
    source_tabnr = source_tabnr,
    source_winnr = winnr,
    maximize_tabnr = maximize_tabnr,
    maximize_winnr = maximize_winnr,
    augroup = augroup,
    closing = false,
  }
  dot.state.maximized.set_normal(normal)
  dot.tab.resolve(maximize_tabnr, true)
  dot.state.status.dirtier_tabline:mark_dirty()

  vim.api.nvim_create_autocmd("TabLeave", {
    group = augroup,
    callback = function()
      on_normal_tab_leave(normal)
    end,
  })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = augroup,
    callback = function()
      if not vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr) then
        dispose_normal(normal)
      end
    end,
  })
end

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---@return nil
function M.toggle()
  local winnr = dot.state.status.get_winnr_command() ---@type integer|nil
  if winnr == nil or winnr < 1 or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  if stl.nvim.win.is_float(winnr) then
    maximize_float(winnr)
  else
    maximize_normal(winnr)
  end
end

---@return boolean
function M.is_zoomed()
  local normal = dot.state.maximized.get_normal() ---@type dot.state.maximized.INormalContext|nil
  if normal == nil then
    return false
  end

  if
    not vim.api.nvim_tabpage_is_valid(normal.maximize_tabnr) or not vim.api.nvim_win_is_valid(normal.maximize_winnr)
  then
    dispose_normal(normal)
    return false
  end

  return true
end

---@return nil
function M.close()
  close_normal(true)
end

return M
