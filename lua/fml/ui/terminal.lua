local api_state = require("fml.api.state")

---@class fml.ui.Terminal : fml.types.ui.ITerminal
---@field protected _alive              boolean
---@field protected _bufnr              integer|nil
---@field protected _command            string
---@field protected _command_cwd        string
---@field protected _command_env        table<string, string>|nil
---@field protected _destroy_on_close   boolean
---@field protected _term_alive         boolean
---@field protected _visible            eve.types.collection.IObservable
---@field protected _winnr              integer|nil
local M = {}
M.__index = M

---@class fml.ui.terminal.IProps
---@field public command                ?string
---@field public command_cwd            ?string
---@field public command_env            ?table<string, string>
---@field public destroy_on_close       boolean

---@param props                         fml.ui.terminal.IProps
---@return fml.ui.Terminal
function M.new(props)
  local self = setmetatable({}, M)

  local command = props.command or vim.env.SHELL or vim.o.shell ---@type string
  local command_cwd = props.command_cwd or eve.path.cwd() ---@type string
  local command_env = props.command_env ---@type table<string, string>|nil
  local destroy_on_close = props.destroy_on_close ---@type boolean
  local visible = eve.c.Observable.from_value(false) ---@type eve.types.collection.IObservable

  self._alive = true
  self._bufnr = nil
  self._command = command
  self._command_cwd = command_cwd
  self._command_env = command_env
  self._destroy_on_close = destroy_on_close
  self._term_alive = false
  self._visible = visible
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
  vim.bo[bufnr].filetype = eve.constants.FT_TERM
  vim.bo[bufnr].swapfile = false

  ---@return nil
  local function on_close()
    self:close()
  end
  vim.keymap.set({ "n", "v" }, "q", on_close, { desc = "close", noremap = true, silent = true })

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
  vim.wo[winnr].winblend = 10
  vim.wo[winnr].wrap = true
  vim.wo[winnr].list = false
  return winnr, bufnr
end

---@return boolean
function M:alive()
  return self._alive
end

---@return nil
function M:close()
  self:hide()

  if self._destroy_on_close then
    self._term_alive = false
    self._alive = false

    if self._bufnr ~= nil and vim.api.nvim_buf_is_valid(self._bufnr) then
      local bufnr = self._bufnr ---@type integer
      self._bufnr = nil
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end
end

---@return nil
function M:focus() end

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
  local winnr_cur = api_state.get_current_tab_winnr() ---@type integer
  vim.api.nvim_tabpage_set_win(0, winnr_cur)

  local winnr = self._winnr ---@type integer|nil
  local visible = self:visible() ---@type boolean

  self._winnr = nil
  self._visible:next(false)

  if visible and winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
end

---@return nil
function M:open()
  eve.widgets.push(self)
  self:show()
end

---@return nil
function M:resize()
  local visible = self:visible() ---@type boolean
  if visible then
    self:create_win_as_needed()
  end
end

---@return nil
function M:show()
  if not self._alive then
    eve.reporter.error({
      from = "fl.ui.terminal",
      subject = "show",
      message = "The widget has been destroyed, cannot open it again.",
      details = {
        alive = self._alive,
        command = self._command,
        command_cwd = self._command_cwd,
        command_env = self._command_env,
      },
    })
    return
  end

  local visible = self:visible() ---@type boolean
  if not visible then
    self._visible:next(true)

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
  end

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

---@return nil
function M:toggle()
  local visible = self:visible() ---@type boolean
  if visible then
    self:hide()
  else
    self:open()
  end
end

---@return boolean
function M:visible()
  return self._visible:snapshot()
end

return M
