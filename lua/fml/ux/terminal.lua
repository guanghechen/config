local fn = require("eve.builtin.fn")
local path = require("eve.builtin.path")
local ft = require("eve.constant.filetype")
local state = require("eve.state")

local TERMINAL_WIN_HIGHLIGHT = table.concat({
  "Cursor:f_us_terminal_current",
  "CursorColumn:f_us_terminal_current",
  "CursorLine:f_us_terminal_current",
  "CursorLineNr:f_us_terminal_current",
  "FloatBorder:f_us_terminal_border",
  "Normal:f_us_terminal_bg",
}, ",")

---@param cmd                           string|nil
local function format_command(cmd)
  local command = {} ---@type string[]
  local shell = vim.env.SHELL or vim.o.shell ---@type string
  if cmd == nil or #cmd < 1 then
    command = { shell }
  else
    command = { shell, "-c", cmd }
  end
  return command
end

---@class fml.ux.ITerminal : eve.t.ux.IWidget
---@field public get_winnr              fun(self: fml.ux.ITerminal): integer|nil
---@field public get_bufnr              fun(self: fml.ux.ITerminal): integer|nil
---@field public is_visible             fun(self: fml.ux.ITerminal): boolean
---@field public show                   fun(self: fml.ux.ITerminal): nil
---@field public toggle                 fun(self: fml.ux.ITerminal): nil
---@field public update                 fun(self: fml.ux.ITerminal, props: fml.ux.terminal.IProps): nil

---@class fml.ux.terminal.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public width                  ?number

---@class fml.ux.terminal.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number

---@class fml.ux.Terminal : fml.ux.ITerminal
---@field protected _bufnr              integer|nil
---@field protected _command            string[]
---@field protected _command_cwd        string
---@field protected _command_env        table<string, string>|nil
---@field protected _keymaps            eve.t.IKeymap[]
---@field protected _permanent          boolean
---@field protected _status             eve.e.WidgetStatus
---@field protected _term_alive         boolean
---@field protected _winnr              integer|nil
---@field protected _on_exit            fun(): nil
local M = {}
M.__index = M

---@class fml.ux.terminal.IProps
---@field public command                ?string
---@field public command_cwd            ?string
---@field public command_env            ?table<string, string>
---@field public keymaps                ?eve.t.IKeymap[]
---@field public permanent              ?boolean
---@field public on_exit                ?fun(): nil

---@param props                         fml.ux.terminal.IProps
---@return fml.ux.Terminal
function M.new(props)
  local keymaps = state.widget.get_keymaps() ---@type eve.t.IKeymap[]
  vim.list_extend(keymaps, props.keymaps or {})

  local command = format_command(props.command) ---@type string[]
  local command_cwd = props.command_cwd or path.cwd() ---@type string
  local command_env = props.command_env ---@type table<string, string>|nil
  local permanent = not not props.permanent ---@type boolean

  local self = setmetatable({}, M)
  self._bufnr = nil
  self._command = command
  self._command_cwd = command_cwd
  self._command_env = command_env
  self._keymaps = keymaps
  self._permanent = permanent
  self._status = "hidden"
  self._term_alive = false
  self._winnr = nil
  self._on_exit = props.on_exit or fn.noop
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
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = ft.TERM
  vim.bo[bufnr].swapfile = false
  fn.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })
  return bufnr, true
end

---@return integer
---@return integer
function M:create_win_as_needed()
  local width = math.ceil(0.9 * vim.o.columns) ---@type integer
  local height = math.ceil(0.9 * vim.o.lines) ---@type integer
  local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
  local col = math.floor((vim.o.columns - width) / 2) ---@type integer
  local winblend = state.theme.transparency:snapshot() and 0 or 10 ---@type integer

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
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    winnr = vim.api.nvim_open_win(bufnr, true, wincfg)
    vim.wo[winnr].cursorline = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].wrap = true
    vim.wo[winnr].list = false
    self._winnr = winnr
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
  end

  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winhighlight = TERMINAL_WIN_HIGHLIGHT
  vim.wo[winnr].winfixbuf = true
  return winnr, bufnr
end

---@return nil
function M:close()
  self:hide()

  if not self._permanent then
    self._status = "closed"
    self._term_alive = false

    local bufnr = self._bufnr ---@type integer
    vim.schedule(function()
      if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end)
  end
end

---@return nil
function M:focus()
  local status = self._status ---@type eve.e.WidgetStatus
  if status == "closed" then
    return
  end

  if not M:focused() then
    self._status = "visible" ---@type eve.e.WidgetStatus

    local winnr, bufnr = self:create_win_as_needed()
    vim.api.nvim_tabpage_set_win(0, winnr)
    if not self._term_alive then
      self._term_alive = true
      vim.fn.termopen(self._command, {
        cwd = self._command_cwd,
        env = self._command_env,
        on_exit = self._on_exit,
      })
      vim.api.nvim_create_autocmd("TermClose", {
        once = true,
        buffer = bufnr,
        callback = function()
          self._bufnr = nil
          self._term_alive = false
          vim.schedule(function()
            if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
              vim.api.nvim_buf_delete(bufnr, { force = true })
            end
          end)
          self:close()
        end,
      })
    end

    vim.schedule(function()
      vim.cmd("startinsert")
    end)
  end
end

---@return nil
function M:focused()
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local winnr = self:get_winnr() ---@type integer|nil
  return winnr == winnr_cur
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
  local winnr = self._winnr ---@type integer|nil
  self._winnr = nil
  self._status = "hidden"

  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
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
  state.widget.open(self)
end

---@return eve.e.WidgetStatus
function M:status()
  return self._status
end

---@return nil
function M:toggle()
  local visible = self._status == "visible" ---@type boolean
  if visible then
    self:hide()
  else
    self._status = "hidden"
    self:show()
  end
end

---@param props                         fml.ux.terminal.IProps
---@return nil
function M:update(props)
  local command = format_command(props.command) ---@type string[]
  self._command = command ---@type string[]
  self._command_cwd = props.command_cwd or self._command_cwd ---@type string
  self._command_env = props.command_env or self._command_env ---@type table<string, string>|nil
  self._on_exit = props.on_exit or self._on_exit
end

return M
