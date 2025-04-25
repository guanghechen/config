local nsnrs = eve.constant.nsnr ---@type eve.constant.nsnr

---@class fml.dressing.ui_attach.popupmenu.IState
---@field public items                  string[][]
---@field public selected               integer
---@field public row                    integer
---@field public col                    integer
---@field public grid                   integer
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

local state = nil ---@type fml.dressing.ui_attach.popupmenu.IState|nil

---@class fml.dressing.ui_attach.popupmenu
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.hide(task)
  if state ~= nil then
    local winnr = state.winnr ---@type integer|nil
    local bufnr = state.bufnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_close(winnr, true)
    end

    if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.show(task)
  local items, selected, row, col, grid = unpack(task)
  if state == nil then
    ---@type fml.dressing.ui_attach.popupmenu.IState
    state = {
      items = items,
      selected = selected,
      row = row,
      col = col,
      grid = grid,
      bufnr = nil,
      winnr = nil,
    }
  else
    state.items = items ---@type string[]
    state.selected = selected ---@type integer
    state.row = row ---@type integer
    state.col = col ---@type integer
    state.grid = grid ---@type integer
  end

  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    state.bufnr = bufnr

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = eve.filetype.UX_CMDLINE
    vim.bo[bufnr].swapfile = false
  end

  local width = math.min(math.floor(vim.o.columns * 0.8), 80) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = 10,
    relative = "editor",
    width = width,
    height = math.min(40, vim.o.lines - 8, #state.items),
    row = 5,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    focusable = false,
  }

  local winnr = state.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
    state.winnr = winnr

    eve.win.set_type(winnr, eve.win.Types.POPUPMENU)
    vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true
    vim.w[winnr][eve.var.Names.FLAG_SOURCEFILE] = false

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].wrap = false
    vim.wo[winnr].winhighlight = "Normal:f_up_normal,FloatBorder:f_up_border,CursorLine:f_up_normal"
  else
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
  end

  local lines = {} ---@type string[]
  for _, item in ipairs(state.items) do
    local word, kind, menu, info = unpack(item) ---@type string, string, string, string
    local line = string.format("%s %s %s %s", word, kind or "", menu or "", info or "") ---@type string
    lines[#lines + 1] = line
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.attach, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim__redraw({ win = winnr, flush = true })
end

return M
