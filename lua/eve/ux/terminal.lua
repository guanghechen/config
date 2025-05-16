local __module_name__ = "eve.ux.terminal" ---@type string

local TERMINAL_WIN_HIGHLIGHT = table.concat({
  "Cursor:f_us_terminal_current",
  "CursorColumn:f_us_terminal_current",
  "CursorLine:f_us_terminal_current",
  "CursorLineNr:f_us_terminal_current",
  "FloatBorder:FloatActiveBorder",
  "FloatTitle:FloatActiveTitle",
  "Normal:f_us_terminal_bg",
}, ",")

---@class eve.ux.ITerminal : std.t.ux.IWidget
---@field public get_winnr              fun(self: eve.ux.ITerminal): integer|nil
---@field public get_bufnr              fun(self: eve.ux.ITerminal): integer|nil
---@field public show                   fun(self: eve.ux.ITerminal): nil
---@field public toggle                 fun(self: eve.ux.ITerminal): nil
---@field public update                 fun(self: eve.ux.ITerminal, props: eve.ux.terminal.IProps): nil

---@class eve.ux.terminal.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public width                  ?number

---@class eve.ux.terminal.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number

---@class eve.ux.Terminal : eve.ux.ITerminal
---@field public title                  string|nil
---@field protected _disposed           boolean
---@field protected _permanent          boolean
---@field protected _bufnr              integer|nil
---@field protected _winnr              integer|nil
---
---@field protected _cmd                string
---@field protected _cmd_cwd            string
---@field protected _cmd_env            table<string, string>|nil
---@field protected _keymaps            std.t.IKeymap[]
---@field protected _term_alive         boolean
---@field protected _on_exit            fun(): nil
local M = {}
M.__index = M

---@class eve.ux.terminal.IProps
---@field public cmd                    ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public keymaps                ?std.t.IKeymap[]
---@field public permanent              ?boolean
---@field public title                  string|nil
---@field public on_exit                ?fun(): nil

---@param props                         eve.ux.terminal.IProps
---@return eve.ux.Terminal
function M.new(props)
  local self = setmetatable({}, M)

  local keymaps = eve.widget.get_keymaps(self) ---@type std.t.IKeymap[]
  vim.list_extend(keymaps, props.keymaps or {})

  local cmd = eve.shell.format_command(props.cmd) ---@type string
  local cmd_cwd = props.cwd or eve.path.cwd() ---@type string
  local cmd_env = props.env ---@type table<string, string>|nil
  local permanent = not not props.permanent ---@type boolean
  local title = props.title ---@type string|nil

  self.title = title
  self._disposed = false
  self._permanent = permanent
  self._bufnr = nil
  self._winnr = nil

  self._cmd = cmd
  self._cmd_cwd = cmd_cwd
  self._cmd_env = cmd_env
  self._keymaps = keymaps
  self._term_alive = false
  self._on_exit = props.on_exit or std.fn.noop
  return self
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  return winnr == self._winnr
end

---@return boolean
function M:isvisible()
  local winnr = self._winnr ---@type integer|nil
  return winnr ~= nil and vim.api.nvim_win_is_valid(winnr)
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local winnr = self._winnr ---@type integer|nil
  local bufnr = self._bufnr ---@type integer|nil
  eve.win.close(winnr)
  eve.buf.close(bufnr)
  self._bufnr = nil
  self._winnr = nil

  self._cmd = nil
  self._cmd_cwd = nil
  self._keymaps = nil
end

---@return nil
function M:close()
  if self._disposed then
    return
  end

  if not self._permanent then
    self:dispose()
    return
  end

  self:hide()
end

---@return nil
function M:focus()
  self:__health__()
  eve.widget.push(self)

  if not self:isfocused() then
    local winnr = self:__create_win_as_needed__()
    vim.api.nvim_tabpage_set_win(0, winnr)

    vim.schedule(function()
      vim.cmd("startinsert")
    end)
  end

  local bufnr = self._bufnr
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) and not self._term_alive then
    self._term_alive = true
    vim.fn.jobstart(self._cmd, {
      cwd = self._cmd_cwd,
      env = self._cmd_env,
      on_exit = self._on_exit,
      term = true,
    })
    vim.api.nvim_create_autocmd("TermClose", {
      once = true,
      buffer = bufnr,
      callback = function()
        self._bufnr = nil
        self._term_alive = false
        self:close()
      end,
    })
  end
end

function M:hide()
  self:__health__()

  local winnr = self._winnr ---@type integer|nil
  self._winnr = nil
  eve.win.close(winnr)
end

---@return integer|nil
function M:get_bufnr()
  self:__health__()
  return self._bufnr
end

---@return integer|nil
function M:get_winnr()
  self:__health__()
  return self._winnr
end

---@return nil
function M:resize()
  self:__health__()

  if self:isvisible() then
    self:__create_win_as_needed__()
  end
end

---@return nil
function M:toggle()
  self:__health__()

  if self:isvisible() then
    self:hide()
  else
    self:focus()
  end
end

---@param props                         eve.ux.terminal.IProps
---@return nil
function M:update(props)
  self:__health__()
  local cmd = eve.shell.format_command(props.cmd) ---@type string

  self.title = props.title ---@type string|nil
  self._cmd = cmd ---@type string
  self._cmd_cwd = props.cwd or self._cmd_cwd ---@type string
  self._cmd_env = props.env or self._cmd_env ---@type table<string, string>|nil
  self._on_exit = props.on_exit or self._on_exit
end

---@protected
---@return integer
---@return boolean
function M:__create_buf_as_needed__()
  local bufnr = self._bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr, false
  end

  bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
  self._bufnr = bufnr

  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].filetype = eve.filetype.TERM
  vim.bo[bufnr].swapfile = false
  eve.nvim.bindkeys(self._keymaps, { bufnr = bufnr, noremap = true, silent = true })
  return bufnr, true
end

---@protected
---@return integer
---@return integer
function M:__create_win_as_needed__()
  local width = math.ceil(0.9 * vim.o.columns) ---@type integer
  local height = math.ceil(0.9 * vim.o.lines) ---@type integer
  local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
  local col = math.floor((vim.o.columns - width) / 2) ---@type integer
  local winblend = eve.context.theme.get_float_winblend() ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    relative = "editor",
    row = row,
    col = col,
    height = height,
    width = width,
    border = "rounded",
    style = "minimal",
    focusable = true,
    title = self.title and " " .. self.title .. " " or nil,
    title_pos = self.title and "center" or nil,
  }

  local winnr = self._winnr ---@type integer|nil
  local bufnr = self:__create_buf_as_needed__() ---@type integer
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    winnr = vim.api.nvim_open_win(bufnr, true, wincfg)

    eve.win.set_type(winnr, eve.win.Types.TERMINAL)
    vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].wrap = true
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

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.name) ---@type string
    error(message)
  end
end

return M
