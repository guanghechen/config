local states = require("fml.dressing.ui_attach.state")

local nsnrs = eve.constant.nsnr ---@type eve.constant.nsnr

---@class fml.dressing.ui_attach.popupmenu
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.hide(task)
  if states.popupmenu ~= nil then
    local winnr = states.popupmenu.winnr ---@type integer|nil
    local bufnr = states.popupmenu.bufnr ---@type integer|nil
    states.popupmenu.winnr = nil
    states.popupmenu.bufnr = nil

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
function M.select(task)
  if states.popupmenu == nil then
    return
  end

  local bufnr = states.popupmenu.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local selected = unpack(task.args) ---@type integer

  states.popupmenu.selected = selected ---@type integer
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.popupmenu_selected, 0, -1)
  if selected >= 0 then
    local row = selected ---@type integer
    vim.hl.range(bufnr, nsnrs.popupmenu_selected, "f_up_selected", { row, 0 }, { row, -1 })
  end
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.show(task)
  local items, selected, row, col, grid = unpack(task.args)
  ---@cast items                        string[][]
  ---@cast selected                     integer
  ---@cast row                          integer
  ---@cast col                          integer
  ---@cast grid                         integer

  if states.popupmenu == nil then
    ---@type fml.dressing.ui_attach.popupmenu.IState
    states.popupmenu = {
      items = items,
      selected = selected,
      row = row,
      col = col,
      grid = grid,
      bufnr = nil,
      winnr = nil,
    }
  else
    states.popupmenu.items = items ---@type string[][]
    states.popupmenu.selected = selected ---@type integer
    states.popupmenu.row = row ---@type integer
    states.popupmenu.col = col ---@type integer
    states.popupmenu.grid = grid ---@type integer
  end

  M._show(states.popupmenu)
end

---@param state                       fml.dressing.ui_attach.popupmenu.IState
---@return nil
function M._show(state)
  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    state.bufnr = bufnr

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = eve.filetype.UX_POPUPMENU
    vim.bo[bufnr].swapfile = false
  end

  local width = math.min(math.floor(vim.o.columns * 0.8), 80) ---@type integer
  local height = math.min(math.floor(vim.o.lines * 0.8), #state.items)

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = 2000,
    relative = "editor",
    width = width,
    height = height,
    row = 6,
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
    local line = word ---@type string
    if type(kind) == "string" and #kind > 0 then
      line = line .. " " .. kind
    end
    if type(menu) == "string" and #menu > 0 then
      line = line .. " " .. menu
    end
    if type(info) == "string" and #info > 0 then
      line = line .. " " .. info
    end

    lines[#lines + 1] = eve.string.pad_end(line, width, " ") ---@type string
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.popupmenu, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.popupmenu_selected, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  if state.selected >= 0 then
    local row = state.selected ---@type integer
    vim.hl.range(bufnr, nsnrs.popupmenu_selected, "f_up_selected", { row, 0 }, { row, -1 })
  end

  vim.api.nvim__redraw({ win = winnr, flush = true })
end

return M
