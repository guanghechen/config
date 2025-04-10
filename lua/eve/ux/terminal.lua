local TERMINAL_WIN_HIGHLIGHT = table.concat({
  "Cursor:f_us_terminal_current",
  "CursorColumn:f_us_terminal_current",
  "CursorLine:f_us_terminal_current",
  "CursorLineNr:f_us_terminal_current",
  "FloatBorder:FloatBorderActive",
  "Normal:f_us_terminal_bg",
}, ",")

---@class eve.ux.ITerminal : eve.t.ux.IWidget
---@field public title                  string|nil
---@field public get_winnr              fun(self: eve.ux.ITerminal): integer|nil
---@field public get_bufnr              fun(self: eve.ux.ITerminal): integer|nil
---@field public is_visible             fun(self: eve.ux.ITerminal): boolean
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
---@field protected _bufnr              integer|nil
---@field protected _cmd                string
---@field protected _cmd_cwd            string
---@field protected _cmd_env            table<string, string>|nil
---@field protected _keymaps            eve.t.IKeymap[]
---@field protected _permanent          boolean
---@field protected _status             eve.e.WidgetStatus
---@field protected _term_alive         boolean
---@field protected _winnr              integer|nil
---@field protected _on_exit            fun(): nil
local M = {}
M.__index = M

---@class eve.ux.terminal.IProps
---@field public cmd                    ?string
---@field public cwd                    ?string
---@field public env                    ?table<string, string>
---@field public keymaps                ?eve.t.IKeymap[]
---@field public permanent              ?boolean
---@field public title                  string|nil
---@field public on_exit                ?fun(): nil

---@param props                         eve.ux.terminal.IProps
---@return eve.ux.Terminal
function M.new(props)
  local self = setmetatable({}, M)

  local keymaps = eve.state.widget.get_keymaps(self) ---@type eve.t.IKeymap[]
  vim.list_extend(keymaps, props.keymaps or {})

  local cmd = eve.shell.format_command(props.cmd) ---@type string
  local cmd_cwd = props.cwd or eve.path.cwd() ---@type string
  local cmd_env = props.env ---@type table<string, string>|nil
  local permanent = not not props.permanent ---@type boolean
  local title = props.title ---@type string|nil

  self.title = title
  self._bufnr = nil
  self._cmd = cmd
  self._cmd_cwd = cmd_cwd
  self._cmd_env = cmd_env
  self._keymaps = keymaps
  self._permanent = permanent
  self._status = "hidden"
  self._term_alive = false
  self._winnr = nil
  self._on_exit = props.on_exit or eve.std.fn.noop
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
  vim.bo[bufnr].filetype = eve.filetype.TERM
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
  local winblend = eve.state.theme.get_float_winblend() ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    relative = "editor",
    anchor = "NW",
    height = height,
    width = width,
    row = row,
    col = col,
    focusable = true,
    title = self.title and " " .. self.title .. " " or nil,
    title_pos = self.title and "center" or nil,
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

  if not self:focused() then
    self._status = "visible" ---@type eve.e.WidgetStatus

    local winnr, bufnr = self:create_win_as_needed()
    vim.api.nvim_tabpage_set_win(0, winnr)
    if not self._term_alive then
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
  eve.state.widget.open(self)
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

---@param props                         eve.ux.terminal.IProps
---@return nil
function M:update(props)
  local cmd = eve.shell.format_command(props.cmd) ---@type string

  self.title = props.title ---@type string|nil
  self._cmd = cmd ---@type string
  self._cmd_cwd = props.cwd or self._cmd_cwd ---@type string
  self._cmd_env = props.env or self._cmd_env ---@type table<string, string>|nil
  self._on_exit = props.on_exit or self._on_exit
end

return M
