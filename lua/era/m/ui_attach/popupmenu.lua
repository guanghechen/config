---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ui_attach.popupmenu" ---@type string

local states = require("era.m.ui_attach.state")

local nsnrs = dot.var.nsnr ---@type dot.var.nsnr

---@class era.m.ui_attach.popupmenu
local M = {}

---@param state                         era.m.ui_attach.popupmenu.IState
---@return nil
local function render_selection(state)
  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.popupmenu_selected, 0, -1)
  local selected = state.selected ---@type integer
  if selected < 0 or selected >= #state.items then
    return
  end

  vim.hl.range(bufnr, nsnrs.popupmenu_selected, "f_up_selected", { selected, 0 }, { selected, -1 })
  local winnr = state.winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_cursor(winnr, { selected + 1, 0 })
  end
end

---@param task                          era.m.ui_attach.ITask
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

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.select(task)
  if states.popupmenu == nil then
    return
  end

  local selected = unpack(task.args) ---@type integer

  states.popupmenu.selected = selected ---@type integer
  render_selection(states.popupmenu)
  local winnr = states.popupmenu.winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim__redraw({ win = winnr, flush = true })
  end
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.show(task)
  local items, selected, row, col, grid = unpack(task.args)
  ---@cast items                        string[][]
  ---@cast selected                     integer
  ---@cast row                          integer
  ---@cast col                          integer
  ---@cast grid                         integer

  if states.popupmenu == nil then
    ---@type era.m.ui_attach.popupmenu.IState
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

---@param state                         era.m.ui_attach.popupmenu.IState
---@return integer
---@return integer
function M._resolve_position(state)
  local row = math.floor(state.row or 0) ---@type integer
  local col = math.floor(state.col or 0) ---@type integer

  if state.grid == -1 and type(vim.g.ui_cmdline_pos) == "table" then
    local cmd_pos = vim.g.ui_cmdline_pos ---@type integer[]|nil
    if cmd_pos ~= nil and #cmd_pos >= 2 then
      row = cmd_pos[1]
      local cmdline = states.get_active_cmdline()
      local offset = state.col ---@type integer
      if cmdline ~= nil then
        local text = cmdline.first .. cmdline.second ---@type string
        offset = vim.fn.strdisplaywidth(text:sub(1, state.col))
      end
      col = cmd_pos[2] + offset
    end
  end

  return row, col
end

---@param state                         era.m.ui_attach.popupmenu.IState
---@return nil
function M._show(state)
  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    state.bufnr = bufnr

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", stl.filetype.UX_POPUPMENU, { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  end

  local width = math.min(math.floor(vim.o.columns * 0.8), 80) ---@type integer
  local height = math.min(math.floor(vim.o.lines * 0.8), #state.items)

  local row, col = M._resolve_position(state)

  local max_row = math.max(0, vim.o.lines - height - 1) ---@type integer
  local max_col = math.max(0, vim.o.columns - width - 1) ---@type integer
  row = math.max(0, math.min(row, max_row))
  col = math.max(0, math.min(col, max_col))

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = dot.var.zindex.POPUPMENU,
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    focusable = false,
  }

  local winnr = state.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
    state.winnr = winnr

    vim.w[winnr].wintype = stl.e.WinTypeEnum.POPUPMENU
    vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("list", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:f_up_normal,FloatBorder:f_up_border,CursorLine:f_up_normal",
      { win = winnr, scope = "local" }
    )
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

    lines[#lines + 1] = stl.string.pad_end(line, width, " ") ---@type string
  end

  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.popupmenu, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  render_selection(state)

  vim.api.nvim__redraw({ win = winnr, flush = true })
end

return M
