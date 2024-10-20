local constants = require("eve.std.constants")
local widgets = require("eve.globals.widgets")
local std_array = require("eve.std.array")
local path = require("eve.std.path")
local api_tab = require("fml.api.tab")

local TERMINAL_WIN_HIGHLIGHT = table.concat({
  "Cursor:f_us_terminal_current",
  "CursorColumn:f_us_terminal_current",
  "CursorLine:f_us_terminal_current",
  "CursorLineNr:f_us_terminal_current",
  "FloatBorder:f_us_terminal_border",
  "Normal:f_us_terminal_bg",
}, ",")

---@class fml.ux.Terminal : t.fml.ux.ITerminal
---@field protected _bufnr              integer|nil
---@field protected _command            string[]
---@field protected _command_cwd        string
---@field protected _command_env        table<string, string>|nil
---@field protected _keymaps            t.eve.IKeymap[]
---@field protected _permanent          boolean
---@field protected _status             t.eve.e.WidgetStatus
---@field protected _term_alive         boolean
---@field protected _winnr              integer|nil
local M = {}
M.__index = M

---@class fml.ux.terminal.IProps
---@field public command                ?string
---@field public command_cwd            ?string
---@field public command_env            ?table<string, string>
---@field public keymaps                ?t.eve.IKeymap[]
---@field public permanent              ?boolean

---@param props                         fml.ux.terminal.IProps
---@return fml.ux.Terminal
function M.new(props)
  local self = setmetatable({}, M)

  local command = {} ---@type string[]
  local shell = vim.env.SHELL or vim.o.shell ---@type string
  if props.command == nil or #props.command < 1 then
    command = { shell }
  else
    command = { shell, "-c", props.command }
  end

  ---@type t.eve.IKeymap[]
  local keymaps = {
    {
      modes = { "n", "v" },
      key = "q",
      callback = function()
        self:close()
      end,
      desc = "close",
    },
  }

  local widget_keymaps = widgets.get_keymaps() ---@type t.eve.IKeymap[]
  std_array.extend(keymaps, widget_keymaps, props.keymaps or {})

  local command_cwd = props.command_cwd or path.cwd() ---@type string
  local command_env = props.command_env ---@type table<string, string>|nil
  local permanent = not not props.permanent ---@type boolean

  self._bufnr = nil
  self._command = command
  self._command_cwd = command_cwd
  self._command_env = command_env
  self._keymaps = keymaps
  self._permanent = permanent
  self._status = "closed"
  self._term_alive = false
  self._winnr = nil

  return self
end

---@return integer
---@return boolean
function M:create_buf_as_needed()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr, false
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nowrite"
  vim.bo[bufnr].filetype = constants.FT_TERM
  vim.bo[bufnr].swapfile = false
  eve.nvim.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })
  return bufnr, true
end

---@return integer
---@return integer
function M:create_win_as_needed()
  local width = math.ceil(0.9 * vim.o.columns) ---@type integer
  local height = math.ceil(0.9 * vim.o.lines) ---@type integer
  local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
  local col = math.floor((vim.o.columns - width) / 2) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    relative = "editor",
    anchor = "NW",
    height = height,
    width = width,
    row = row,
    col = col,
    focusable = true,
    title = "",
    border = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    style = "minimal",
  }

  local winnr = self._winnr ---@type integer|nil
  local bufnr = self:create_buf_as_needed() ---@type integer
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
  else
    winnr = vim.api.nvim_open_win(bufnr, true, wincfg)
    self._winnr = winnr
  end

  vim.wo[winnr].cursorline = false
  vim.wo[winnr].number = false
  vim.wo[winnr].signcolumn = "no"
  vim.wo[winnr].winhighlight = TERMINAL_WIN_HIGHLIGHT
  vim.wo[winnr].winblend = 10
  vim.wo[winnr].wrap = true
  vim.wo[winnr].list = false
  return winnr, bufnr
end

---@return nil
function M:close()
  self:hide()

  if not self._permanent then
    self._status = "closed"
    self._term_alive = false
    if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
      local bufnr = self._bufnr ---@type integer
      self._bufnr = nil
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

---@return nil
function M:focus()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local winnr = self:get_winnr() ---@type integer|nil
  local status = self._status ---@type t.eve.e.WidgetStatus
  local visible = status == "visible" ---@type boolean

  if not visible or winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    self:open()
    return
  end

  if winnr_cur ~= winnr then
    vim.schedule(function()
      if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
        vim.api.nvim_tabpage_set_win(0, winnr)
      end
    end)
  end
end

---@return integer|nil
function M:get_bufnr()
  return self._bufnr
end

---@return integer|nil
function M:get_winnr()
  return self._winnr
end

---@return nil
function M:hide()
  local winnr_cur = api_tab.get_current_winnr() ---@type integer
  vim.api.nvim_tabpage_set_win(0, winnr_cur)

  local winnr = self._winnr ---@type integer|nil
  local visible = self._status == "visible" ---@type boolean

  self._winnr = nil
  self._status = "hidden"

  if visible and winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
end

---@return nil
function M:open()
  widgets.push(self)
  self:show()
end

---@return nil
function M:resize()
  local visible = self._status == "visible" ---@type boolean
  if visible then
    self:create_win_as_needed()
  end
end

---@return nil
function M:show()
  local visible = self._status == "visible" ---@type boolean
  if visible then
    return
  end

  self._status = "visible" ---@type t.eve.e.WidgetStatus

  local winnr, bufnr = self:create_win_as_needed()
  vim.api.nvim_tabpage_set_win(0, winnr)
  if not self._term_alive then
    self._term_alive = true
    vim.fn.termopen(self._command, { cwd = self._command_cwd, env = self._command_env })
    vim.api.nvim_create_autocmd("TermClose", {
      once = true,
      buffer = bufnr,
      callback = function()
        self._bufnr = nil
        self._term_alive = false

        if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
        self:close()
      end,
    })
  end

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

---@return t.eve.e.WidgetStatus
function M:status()
  return self._status
end

---@return nil
function M:toggle()
  local visible = self._status == "visible" ---@type boolean
  if visible then
    self:hide()
  else
    self:open()
  end
end

return M
