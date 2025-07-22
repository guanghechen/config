local __module_name__ = "eve.ux.widget.terminal" ---@type string

---@class eve.ux.widget.terminal.IToggleHardParams : eve.builtin.term.ICreateParams
---@field public selected_text          string|nil

local TERMINAL_WIN_HIGHLIGHT = table.concat({
  "Cursor:f_us_terminal_current",
  "CursorColumn:f_us_terminal_current",
  "CursorLine:f_us_terminal_current",
  "CursorLineNr:f_us_terminal_current",
  "FloatBorder:FloatActiveBorder",
  "FloatTitle:FloatActiveTitle",
  "Normal:f_us_terminal_bg",
}, ",")

local _terminal_winnr = nil ---@type integer|nil

---@type eve.ux.nvimbar.Nvimbar
local termline = eve.ux.nvimbar.Nvimbar.new({
  name = "termline",
  comp_sep = "",
  comp_sep_hlname = "f_wl_bg",
  comp_sep_hlname_active = "f_wl_bg",
  delay = 128,
  silent = function()
    local devmode = eve.context.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    return vim.o.columns - 2
  end,
  get_preset_context = function()
    return {
      winnr = _terminal_winnr,
    }
  end,
  is_active = function()
    return _terminal_winnr ~= nil and vim.api.nvim_win_is_valid(_terminal_winnr)
  end,
  on_fulfilled = function(result)
    if _terminal_winnr ~= nil and vim.api.nvim_win_is_valid(_terminal_winnr) then
      vim.wo[_terminal_winnr].winbar = result
    end
  end,
})

local c = eve.ux.nvimbar.component
local position = "f_wl" ---@type eve.ux.nvimbar.PositionEnum
termline:place("left", c.term.terms(position), 100)

std.fn.observe({ eve.term.o_bufnr }, function()
  local winnr = _terminal_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local bufnr_current = vim.api.nvim_win_get_buf(winnr) ---@type integer
  local bufnr = eve.term.o_bufnr:snapshot() ---@type integer
  if bufnr == bufnr_current then
    return
  end

  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.wo[winnr].winfixbuf = true
  end
  eve.status.dirtier_termline:mark_dirty()
end, true)

eve.status.dirtier_termline:subscribe(
  std.Subscriber.new({
    on_next = function()
      termline:render()
    end,
  }),
  true
)

---@class eve.ux.widget.Terminal : std.t.ux.IWidget
local M = {}

---@return boolean
function M:isdisposed()
  return false
end

---@return boolean
function M:isfocused()
  local winnr_current = vim.api.nvim_get_current_win() ---@type integer
  return winnr_current == _terminal_winnr
end

---@return boolean
function M:isvisible()
  return _terminal_winnr ~= nil and vim.api.nvim_win_is_valid(_terminal_winnr)
end

---@return nil
function M:dispose() end

---@return nil
function M:close()
  self:hide()
end

---@return integer|nil
function M:focus()
  eve.widget.push(self)

  local termmeta = eve.term.current() ---@type eve.builtin.term.IMeta|nil
  if termmeta == nil then
    eve.win.close(_terminal_winnr)
    _terminal_winnr = nil
    return
  end

  local winnr = self:__create_win_as_needed__(termmeta)
  vim.api.nvim_set_current_win(winnr)
  self:__start__(termmeta)

  eve.term.on_focused(termmeta)
end

---@return nil
function M:hide()
  local winnr = _terminal_winnr ---@type integer|nil
  _terminal_winnr = nil
  eve.win.close(winnr)
end

---@return nil
function M:show()
  self:focus()
end

---@return integer|nil
function M:get_bufnr()
  local termmeta = eve.term.current() ---@type eve.builtin.term.IMeta|nil
  return termmeta and termmeta.bufnr or nil ---@type integer|nil
end

---@return integer|nil
function M:get_winnr()
  return _terminal_winnr
end

---@return nil
function M:resize()
  if self:isvisible() then
    local termmeta = eve.term.current() ---@type eve.builtin.term.IMeta|nil
    if termmeta == nil then
      eve.win.close(_terminal_winnr)
      _terminal_winnr = nil
    else
      self:__create_win_as_needed__(termmeta)
    end
  end
end

---@return nil
function M:toggle()
  if self:isvisible() then
    self:hide()
  else
    self:focus()
  end
end

---@class eve.ux.widget.terminal.IToggleAndFocusParams : eve.builtin.term.ICreateParams
---@field public selected_text          string|nil
---@field public autofocus              boolean|nil

---@param params                        eve.ux.widget.terminal.IToggleAndFocusParams
---@return nil
function M:toggle_and_focus(params)
  local uuid = params.uuid ---@type string
  local name = params.name ---@type string
  local termmeta = eve.term.resolve_by_name(name) ---@type eve.builtin.term.IMeta|nil
  if termmeta == nil then
    termmeta = eve.term.create({
      uuid = uuid,
      name = name,
      cmd = params.cmd,
      cwd = params.cwd,
      env = params.env,
      permanent = params.permanent,
      hidewipe = params.hidewipe,
      keymaps = params.keymaps,
      on_closed = params.on_closed,
      on_focused = params.on_focused,
      on_resized = params.on_resized,
    })
  else
    eve.term.update(termmeta, {
      name = name,
      cmd = params.cmd,
      env = params.env,
      on_closed = params.on_closed,
      on_focused = params.on_focused,
      on_resized = params.on_resized,
    })
  end

  if self:isvisible() then
    self:hide()
    return
  end

  if params.autofocus then
    eve.term.o_bufnr:next(termmeta.bufnr)
  end

  self:focus()

  local selected_text = params.selected_text ---@type string|nil
  if selected_text ~= nil and #selected_text > 0 then
    vim.schedule(function()
      if self:isfocused() then
        if termmeta.jobid ~= nil then
          local ok, reason = pcall(function()
            vim.api.nvim_chan_send(termmeta.jobid, selected_text)
          end)
          if not ok then
            std.reporter.error({
              from = __module_name__,
              subject = "toggle_and_focus",
              message = "Failed to send content to the target terminal",
              details = {
                selected_text = selected_text,
                reason = reason,
              },
            })
          end
        end
      end
    end)
  end
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@param termmeta                      eve.builtin.term.IMeta
---@return integer
function M.__create_buf_as_needed__(termmeta)
  local bufnr = termmeta.bufnr ---@type integer|nil
  if bufnr ~= nil and bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = eve.filetype.TERM
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false
  eve.nvim.bindkeys(termmeta.keymaps, { bufnr = bufnr, noremap = true, silent = true })
  termmeta.bufnr = bufnr
  return bufnr
end

---@protected
---@param termmeta                      eve.builtin.term.IMeta
---@return integer
function M:__create_win_as_needed__(termmeta)
  local width = vim.o.columns - 2 ---@type integer
  local height = vim.o.lines - 3 ---@type integer
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
    title = " Terminal ",
    title_pos = "center",
  }

  local winnr = _terminal_winnr ---@type integer|nil
  local bufnr = M.__create_buf_as_needed__(termmeta) ---@type integer
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    winnr = vim.api.nvim_open_win(bufnr, true, wincfg)
    eve.win.set_type(winnr, eve.win.Types.TERMINAL)

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].winfixbuf = true
    vim.wo[winnr].wrap = true
    _terminal_winnr = winnr

    vim.schedule(function()
      vim.cmd("startinsert")
    end)
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.wo[winnr].winfixbuf = true
  end

  vim.wo[winnr].winblend = winblend
  vim.wo[winnr].winhighlight = TERMINAL_WIN_HIGHLIGHT
  eve.status.dirtier_termline:mark_dirty()

  termmeta.on_resized()
  return winnr
end

---@protected
---@param termmeta                      eve.builtin.term.IMeta
---@return nil
function M:__start__(termmeta)
  if termmeta.jobid == nil then
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = self:__create_win_as_needed__(termmeta) ---@type integer
    vim.api.nvim_tabpage_set_win(tabnr, winnr)

    local channelid = vim.fn.jobstart(termmeta.cmd, {
      cwd = termmeta.cwd,
      env = termmeta.env,
      pty = true,
      term = true,
      detach = false,
      on_exit = function(jobid, code, event)
        if code ~= 0 then
          std.reporter.error({
            from = __module_name__,
            subject = "terminal unexpected exit",
            details = {
              termmeta = {
                uuid = termmeta.uuid,
                name = termmeta.name,
                cmd = termmeta.cmd,
                cwd = termmeta.cwd,
                env = termmeta.env,
                permanent = termmeta.permanent,
                hidewipe = termmeta.hidewipe,
                code = code,
                event = event,
              },
            },
          })
        end

        if termmeta.jobid == jobid then
          termmeta.jobid = nil
          eve.term.on_closed(termmeta)
        end
      end,
    })
    termmeta.jobid = channelid
  end
end

return M
