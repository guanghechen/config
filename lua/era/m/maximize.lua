local WINHIGHLIGHT_FLOAT = "NormalFloat:f_maximize_float_normal,FloatBorder:f_maximize_float_border"
local WINHIGHLIGHT_NORMAL = "NormalFloat:f_maximize_normal,FloatBorder:f_maximize_normal"

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
  vim.wo[winnr].winblend = original.winblend or 0
  vim.wo[winnr].winhighlight = original.winhighlight or ""
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
  local winblend = vim.wo[winnr].winblend or 0 ---@type integer
  local winhighlight = vim.wo[winnr].winhighlight or "" ---@type string

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

  vim.wo[winnr].winblend = dot.context.theme.get_float_winblend()
  vim.wo[winnr].winhighlight = WINHIGHLIGHT_FLOAT
end

----------------------------------------------------------------------------------------------------
-- Normal window maximize
----------------------------------------------------------------------------------------------------

---@return { row: integer, height: integer }
local function calc_main_area()
  local top = stl.nvim.fn.is_tabline_visible() and 1 or 0 ---@type integer
  local bottom = vim.o.cmdheight + (stl.nvim.fn.is_statusline_visible() and 1 or 0) ---@type integer
  local height = vim.o.lines - top - bottom - 2 ---@type integer
  return { row = top, height = math.max(1, height) }
end

---@return nil
local function close_normal()
  local original = dot.state.maximized.get_original_normal() ---@type dot.state.maximized.IOriginalNormalWindow|nil
  if original == nil then
    return
  end

  dot.state.maximized.clear_original_normal()
  pcall(vim.api.nvim_del_augroup_by_id, original.augroup)

  if vim.api.nvim_win_is_valid(original.float_winnr) then
    vim.api.nvim_win_close(original.float_winnr, true)
  end

  if vim.api.nvim_win_is_valid(original.parent_winnr) then
    vim.api.nvim_set_current_win(original.parent_winnr)
  end
end

---@param winnr                         integer
---@return nil
local function maximize_normal(winnr)
  local original = dot.state.maximized.get_original_normal() ---@type dot.state.maximized.IOriginalNormalWindow|nil
  if original ~= nil and vim.api.nvim_win_is_valid(original.float_winnr) then
    close_normal()
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local view = vim.fn.winsaveview() ---@type table
  local main = calc_main_area() ---@type { row: integer, height: integer }

  ---@type integer
  local float_winnr = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    row = main.row,
    col = 0,
    width = vim.o.columns,
    height = main.height,
    style = "minimal",
    zindex = dot.win.resolve_zindex(),
  })

  local wo = vim.wo[float_winnr]
  wo.winhighlight = WINHIGHLIGHT_NORMAL
  wo.winblend = dot.context.theme.get_float_winblend()
  wo.number = true
  wo.relativenumber = dot.context.option.relativenumber:snapshot()
  wo.signcolumn = "yes"
  wo.cursorline = true
  wo.wrap = false
  wo.foldcolumn = "0"

  vim.fn.winrestview(view)

  local augroup = vim.api.nvim_create_augroup("era_maximize_normal", { clear = true }) ---@type integer
  dot.state.maximized.set_original_normal({
    parent_winnr = winnr,
    float_winnr = float_winnr,
    augroup = augroup,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    callback = function()
      local o = dot.state.maximized.get_original_normal()
      if o ~= nil and vim.api.nvim_win_is_valid(o.parent_winnr) then
        local cursor = vim.api.nvim_win_get_cursor(o.float_winnr) ---@type integer[]
        pcall(vim.api.nvim_win_set_cursor, o.parent_winnr, cursor)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    callback = function()
      local o = dot.state.maximized.get_original_normal()
      if o ~= nil and vim.api.nvim_win_is_valid(o.parent_winnr) then
        local buf = vim.api.nvim_win_get_buf(o.float_winnr) ---@type integer
        pcall(vim.api.nvim_win_set_buf, o.parent_winnr, buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinEnter", {
    group = augroup,
    callback = function()
      local o = dot.state.maximized.get_original_normal()
      if o == nil then
        return
      end

      local cur_winnr = vim.api.nvim_get_current_win() ---@type integer
      if cur_winnr == o.float_winnr then
        return
      end

      local cfg = vim.api.nvim_win_get_config(cur_winnr) ---@type vim.api.keyset.win_config
      if cfg.relative == "" then
        vim.schedule(close_normal)
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(float_winnr),
    callback = close_normal,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      local o = dot.state.maximized.get_original_normal()
      if o == nil or not vim.api.nvim_win_is_valid(o.float_winnr) then
        return
      end

      local new_main = calc_main_area() ---@type { row: integer, height: integer }
      pcall(vim.api.nvim_win_set_config, o.float_winnr, {
        relative = "editor",
        row = new_main.row,
        col = 0,
        width = vim.o.columns,
        height = new_main.height,
      })
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

  local original_normal = dot.state.maximized.get_original_normal() ---@type dot.state.maximized.IOriginalNormalWindow|nil
  if original_normal ~= nil and original_normal.float_winnr == winnr then
    close_normal()
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
  local original = dot.state.maximized.get_original_normal() ---@type dot.state.maximized.IOriginalNormalWindow|nil
  if original == nil then
    return false
  end

  if not vim.api.nvim_win_is_valid(original.float_winnr) then
    dot.state.maximized.clear_original_normal()
    return false
  end

  return true
end

---@return nil
function M.close()
  close_normal()
end

return M
