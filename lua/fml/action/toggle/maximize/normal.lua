local WINHIGHLIGHT = "NormalFloat:f_maximize_normal,FloatBorder:f_maximize_normal"

---@class fml.action.toggle.maximize.normal
local M = {}

---@return { row: integer, height: integer }
local function calc_main_area()
  local top = eve.nvim.is_tabline_visible() and 1 or 0 ---@type integer
  local bottom = vim.o.cmdheight + (eve.nvim.is_statusline_visible() and 1 or 0) ---@type integer
  local height = vim.o.lines - top - bottom - 2 ---@type integer
  return { row = top, height = math.max(1, height) }
end

---@return nil
local function close()
  local original = eve.state.maximized.get_original_normal() ---@type eve.state.maximized.IOriginalNormalWindow|nil
  if original == nil then
    return
  end

  eve.state.maximized.clear_original_normal()
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
function M.maximize(winnr)
  local original = eve.state.maximized.get_original_normal() ---@type eve.state.maximized.IOriginalNormalWindow|nil
  if original ~= nil and vim.api.nvim_win_is_valid(original.float_winnr) then
    close()
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
    zindex = eve.state.maximized.context.MAXIMIZED_ZINDEX,
  })

  local wo = vim.wo[float_winnr]
  wo.winhighlight = WINHIGHLIGHT
  wo.winblend = eve.context.theme.get_float_winblend()
  wo.number = true
  wo.relativenumber = eve.context.option.relativenumber:snapshot()
  wo.signcolumn = "yes"
  wo.cursorline = true
  wo.wrap = false
  wo.foldcolumn = "0"

  vim.fn.winrestview(view)

  local augroup = vim.api.nvim_create_augroup("fml_maximize_normal", { clear = true }) ---@type integer
  eve.state.maximized.set_original_normal({
    parent_winnr = winnr,
    float_winnr = float_winnr,
    augroup = augroup,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = augroup,
    callback = function()
      local o = eve.state.maximized.get_original_normal()
      if o ~= nil and vim.api.nvim_win_is_valid(o.parent_winnr) then
        local cursor = vim.api.nvim_win_get_cursor(o.float_winnr) ---@type integer[]
        pcall(vim.api.nvim_win_set_cursor, o.parent_winnr, cursor)
      end
    end,
  })

  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = augroup,
    callback = function()
      local o = eve.state.maximized.get_original_normal()
      if o ~= nil and vim.api.nvim_win_is_valid(o.parent_winnr) then
        local buf = vim.api.nvim_win_get_buf(o.float_winnr) ---@type integer
        pcall(vim.api.nvim_win_set_buf, o.parent_winnr, buf)
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinEnter", {
    group = augroup,
    callback = function()
      local o = eve.state.maximized.get_original_normal()
      if o == nil then
        return
      end

      local cur_winnr = vim.api.nvim_get_current_win() ---@type integer
      if cur_winnr == o.float_winnr then
        return
      end

      local cfg = vim.api.nvim_win_get_config(cur_winnr) ---@type vim.api.keyset.win_config
      if cfg.relative == "" then
        vim.schedule(close)
      end
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = augroup,
    pattern = tostring(float_winnr),
    callback = close,
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
      local o = eve.state.maximized.get_original_normal()
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

---@return boolean
function M.is_zoomed()
  local original = eve.state.maximized.get_original_normal() ---@type eve.state.maximized.IOriginalNormalWindow|nil
  if original == nil then
    return false
  end

  if not vim.api.nvim_win_is_valid(original.float_winnr) then
    eve.state.maximized.clear_original_normal()
    return false
  end

  return true
end

---@return nil
function M.close()
  close()
end

return M
