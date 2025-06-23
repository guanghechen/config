---@class fml.action.toggle.maximize
local M = {}

---@type string
local WIN_HIGHLIGHT = table.concat({
  "Cursor:f_ut_current",
  "CursorColumn:f_ut_current",
  "CursorLine:f_ut_current",
  "CursorLineNr:f_ut_current",
  "FloatBorder:FloatActiveBorder",
  "Normal:f_ut_normal",
}, ",")

---@return nil
function M.maximize()
  local winnr_command = eve.status.get_winnr_command() ---@type integer|nil
  if winnr_command == nil or winnr_command < 1 or not vim.api.nvim_win_is_valid(winnr_command) then
    return
  end

  local meta_command = eve.win.resolve(winnr_command, false) ---@type eve.builtin.win.IMeta|nil
  if meta_command ~= nil and meta_command.wintype == eve.win.Types.MAXIMIZE then
    vim.api.nvim_win_close(winnr_command, true)
    return
  end

  local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
  local winnrs = vim.api.nvim_tabpage_list_wins(tabnr) ---@type integer[]
  for _, winnr in ipairs(winnrs) do
    local meta = eve.win.resolve(winnr, false) ---@type eve.builtin.win.IMeta|nil
    if meta ~= nil and meta.wintype == eve.win.Types.MAXIMIZE then
      vim.api.nvim_tabpage_set_win(tabnr, winnr)
      return
    end
  end

  local bufnr = vim.api.nvim_win_get_buf(winnr_command) ---@type integer
  if eve.buf.is_valid(bufnr) then
    local winnr = vim.api.nvim_open_win(bufnr, false, {
      relative = "editor",
      anchor = "NW",
      row = 1,
      col = 0,
      width = vim.o.columns - 2,
      height = vim.o.lines - 4,
      border = "rounded",
      style = "minimal",
      noautocmd = true,
      focusable = true,
      title = " MAXIMIZED ",
      title_pos = "center",
    })

    eve.win.set_type(winnr, eve.win.Types.MAXIMIZE)
    vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true

    vim.wo[winnr].number = true
    vim.wo[winnr].relativenumber = true
    vim.wo[winnr].signcolumn = "yes"
    vim.wo[winnr].winhighlight = WIN_HIGHLIGHT
    vim.wo[winnr].wrap = false

    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_tabpage_set_win(tabnr, winnr)
  end
end

return M
