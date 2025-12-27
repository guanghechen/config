local __module_name__ = "dot.module.term.widget" ---@type string

require("dot.module.term.types")

local c = require("dot.module.nvimbar").component
local Nvimbar = require("dot.module.nvimbar").Nvimbar

local TERMINAL_WIN_HIGHLIGHT = table.concat({
  "Cursor:f_us_terminal_current",
  "CursorColumn:f_us_terminal_current",
  "CursorLine:f_us_terminal_current",
  "CursorLineNr:f_us_terminal_current",
  "FloatBorder:FloatActiveBorder",
  "FloatTitle:FloatActiveTitle",
  "Normal:f_us_terminal_bg",
}, ",")

local _terminal_mask_bufnr = nil ---@type integer|nil
local _terminal_winnr = nil ---@type integer|nil

---@return integer
local function create_mask_buf_as_needed()
  local bufnr = _terminal_mask_bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    _terminal_mask_bufnr = bufnr

    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].filetype = ark.filetype.TERM_MASK
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].readonly = true
    vim.bo[bufnr].swapfile = false
  end
  return bufnr
end

---@type dot.module.nvimbar.Nvimbar
local termline = Nvimbar.new({
  name = "termline",
  comp_sep = "",
  comp_sep_hlname = "f_wl_bg",
  comp_sep_hlname_active = "f_wl_bg",
  delay = 128,
  silent = function()
    local devmode = dot.context.flight.devmode:snapshot() ---@type boolean
    return not devmode
  end,
  get_max_width = function()
    local winnr = _terminal_winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      local width = vim.api.nvim_win_get_width(winnr) ---@type integer
      return math.max(0, width - 2)
    end
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

local position = "f_wl" ---@type ark.e.NvimbarPositionEnum
termline:place("left", c.term.items(position), 95):place("left", c.term.add_button(position), 100)

ark.fn.observe({ dot.term.state.o_termuuid }, function()
  local winnr = _terminal_winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local termuuid = dot.term.state.o_termuuid:snapshot() ---@type string
  local termmeta = dot.term.state.get(termuuid) ---@type dot.module.term.IMeta|nil
  if termmeta == nil or termmeta.bufnr <= 0 or not vim.api.nvim_buf_is_valid(termmeta.bufnr) then
    return
  end

  local bufnr_current = vim.api.nvim_win_get_buf(winnr) ---@type integer
  if termmeta.bufnr == bufnr_current then
    return
  end

  vim.wo[winnr].winfixbuf = false
  vim.api.nvim_win_set_buf(winnr, termmeta.bufnr)
  vim.wo[winnr].winfixbuf = true
  dot.state.status.dirtier_termline:mark_dirty()
end, true)

dot.state.status.dirtier_termline:subscribe(
  ark.c.Subscriber.new({
    on_next = function()
      termline:render()
    end,
  }),
  true
)

---@param winnr                         integer
---@return nil
local function render_winbar_to(winnr)
  if not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local prev_winnr = _terminal_winnr
  _terminal_winnr = winnr
  local result = termline:render(true)
  _terminal_winnr = prev_winnr

  vim.wo[winnr].winbar = result
end

---@param direction                     'h'|'j'|'k'|'l'
---@return integer
local function split_window(direction)
  if direction == "h" then
    vim.o.splitright = false
    vim.cmd("vsplit")
    vim.o.splitright = true
  elseif direction == "j" then
    vim.o.splitbelow = true
    vim.cmd("split")
  elseif direction == "k" then
    vim.o.splitbelow = false
    vim.cmd("split")
    vim.o.splitbelow = true
  else
    vim.o.splitright = true
    vim.cmd("vsplit")
  end
  return vim.api.nvim_get_current_win()
end

---@param termmeta                      dot.module.term.IMeta
---@return ark.t.IKeymap[]
local function create_default_keymaps(termmeta)
  local keymaps = {} ---@type ark.t.IKeymap[]
  for i = 1, 9 do
    local key = string.format("<C-%d>", i) ---@type string
    local definition = dot.command.definitions.term["focus_" .. tostring(i)] ---@type dot.command.IDefinition
    keymaps[#keymaps + 1] = {
      modes = { "i", "n", "t", "x" },
      key = key,
      desc = definition.desc,
      callback = function()
        definition:execute()
      end,
    }
  end
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-,>",
    aliases = { "<C-[>" },
    desc = dot.command.definitions.term.focus_left.desc,
    callback = function()
      dot.command.definitions.term.focus_left:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-.>",
    aliases = { "<C-]>" },
    desc = dot.command.definitions.term.focus_right.desc,
    callback = function()
      dot.command.definitions.term.focus_right:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-S-,>",
    aliases = { "<C-S-[>" },
    desc = dot.command.definitions.term.swap_left.desc,
    callback = function()
      dot.command.definitions.term.swap_left:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-S-.>",
    aliases = { "<C-S-]>" },
    desc = dot.command.definitions.term.swap_right.desc,
    callback = function()
      dot.command.definitions.term.swap_right:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-n>",
    desc = dot.command.definitions.term.rename.desc,
    callback = function()
      dot.command.definitions.term.rename:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-/>",
    desc = dot.command.definitions.term.create.desc,
    callback = function()
      dot.command.definitions.term.create:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<C-d>",
    desc = dot.command.definitions.term.destroy.desc,
    callback = function()
      dot.command.definitions.term.destroy:execute()
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "i", "n", "t", "x" },
    key = "<esc>",
    desc = "term: feedback esc to terminal (fix the conflict caused by  the csi u)",
    expr = true,
    replace_keycodes = true,
    callback = function()
      return "<esc>"
    end,
  }
  keymaps[#keymaps + 1] = {
    modes = { "n", "x" },
    key = "q",
    desc = "term: close",
    callback = function()
      local _, meta = dot.term.state.indexof_by_bufnr(termmeta.bufnr)
      if meta then
        dot.term.event.on_closed(meta)
      end
    end,
  }
  return keymaps
end

---@class dot.module.term.widget : dot.t.IWidget
local M = {}

M.name = "terminal"

---@return nil
function M:close()
  self:hide()
end

---@return nil
function M:dispose() end

---@return integer|nil
function M:focus()
  dot.state.widget.push(self)

  local termindex = dot.term.state.current() ---@type integer
  local _, termmeta = dot.term.state.at(termindex) ---@type string|nil, dot.module.term.IMeta|nil
  if termmeta == nil then
    dot.win.close(_terminal_winnr)
    _terminal_winnr = nil
    return
  end

  local winnr = self:__create_win_as_needed__(termmeta)
  vim.api.nvim_set_current_win(winnr)
  self:__start__(termmeta)

  dot.term.event.on_focused(termmeta)
end

---@return integer|nil
function M:get_bufnr()
  local termindex = dot.term.state.current() ---@type integer
  local _, termmeta = dot.term.state.at(termindex) ---@type string|nil, dot.module.term.IMeta|nil
  return termmeta and termmeta.bufnr or nil
end

---@return integer|nil
function M:get_winnr()
  return _terminal_winnr
end

---@return nil
function M:hide()
  local winnr = _terminal_winnr ---@type integer|nil
  _terminal_winnr = nil
  dot.win.close(winnr)
end

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
function M:resize()
  if self:isvisible() then
    local termindex = dot.term.state.current() ---@type integer
    local _, termmeta = dot.term.state.at(termindex) ---@type string|nil, dot.module.term.IMeta|nil
    if termmeta == nil then
      dot.win.close(_terminal_winnr)
      _terminal_winnr = nil
    else
      self:__create_win_as_needed__(termmeta)
    end
  end
end

---@return nil
function M:show()
  self:focus()
end

---@param direction                     'h'|'j'|'k'|'l'
---@return nil
function M:split(direction)
  local winnr_original = vim.api.nvim_get_current_win() ---@type integer
  if dot.win.is_float(winnr_original) then
    return
  end

  local termindex = dot.term.state.current() ---@type integer
  local _, termmeta = dot.term.state.at(termindex) ---@type string|nil, dot.module.term.IMeta|nil
  if termmeta == nil then
    termmeta = dot.term.state.create({
      uuid = yoz.fn.uuid(),
      name = "Terminal",
      type = "shell",
      permanent = true,
    })
  end

  local winnr_new = split_window(direction) ---@type integer
  local bufnr = M.__create_buf_as_needed__(termmeta) ---@type integer
  vim.api.nvim_win_set_buf(winnr_new, bufnr)

  vim.wo[winnr_new].cursorline = false
  vim.wo[winnr_new].list = false
  vim.wo[winnr_new].number = false
  vim.wo[winnr_new].relativenumber = false
  vim.wo[winnr_new].signcolumn = "no"
  vim.wo[winnr_new].spell = false
  vim.wo[winnr_new].wrap = true
  vim.wo[winnr_new].winfixbuf = true

  render_winbar_to(winnr_new)
  self:__start_job__(termmeta)

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

---@return nil
function M:toggle()
  if self:isvisible() then
    self:hide()
  else
    self:focus()
  end
end

---@param params                        dot.module.term.IToggleAndFocusParams
---@return nil
function M:toggle_and_focus(params)
  local termuuid = params.uuid ---@type string
  local name = params.name ---@type string
  local typ = params.type ---@type string
  local autofocus = not not params.autofocus ---@type boolean
  local _, termuuid_current = dot.term.state.current() ---@type integer, string|nil

  local termmeta = dot.term.state.get(termuuid) ---@type dot.module.term.IMeta|nil
  if termmeta == nil then
    termmeta = dot.term.state.create({
      uuid = termuuid,
      type = typ,
      name = name,
      cmd = params.cmd,
      cwd = params.cwd,
      env = params.env,
      permanent = params.permanent,
      hidewipe = params.hidewipe,
      user_keymaps = params.user_keymaps,
      on_closed = params.on_closed,
      on_focused = params.on_focused,
      on_resized = params.on_resized,
    })
  else
    dot.term.state.update(termmeta, {
      name = name,
      type = typ,
      cmd = params.cmd,
      env = params.env,
      on_closed = params.on_closed,
      on_focused = params.on_focused,
      on_resized = params.on_resized,
    })

    dot.term.state.append(termuuid)
  end

  if self:isvisible() then
    if termuuid == termuuid_current or not autofocus then
      self:hide()
      return
    end
  end

  if autofocus then
    dot.term.state.o_termuuid:next(termmeta.uuid)
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
            ark.reporter.error({
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
---@param termmeta                      dot.module.term.IMeta
---@return integer
function M.__create_buf_as_needed__(termmeta)
  local bufnr = termmeta.bufnr ---@type integer
  if bufnr > 0 and vim.api.nvim_buf_is_valid(bufnr) then
    return bufnr
  end

  bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].buflisted = false
  vim.bo[bufnr].filetype = ark.filetype.TERM
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = false
  vim.bo[bufnr].swapfile = false

  if termmeta.hidewipe then
    vim.bo[bufnr].bufhidden = "wipe"
  end

  vim.api.nvim_create_autocmd("TermClose", {
    buffer = bufnr,
    callback = function()
      vim.schedule(function()
        local _, _termmeta = dot.term.state.indexof_by_bufnr(bufnr)
        if _termmeta then
          dot.term.event.on_closed(_termmeta)
        else
          dot.buf.close(bufnr)
        end
      end)
    end,
  })

  termmeta.bufnr = bufnr
  local default_keymaps = create_default_keymaps(termmeta) ---@type ark.t.IKeymap[]
  ark.nvim.bindkeys(default_keymaps, { bufnr = bufnr, noremap = true, silent = true })
  ark.nvim.bindkeys(termmeta.user_keymaps, { bufnr = bufnr, noremap = true, silent = true })

  return bufnr
end

---@protected
---@param termmeta                      dot.module.term.IMeta
---@return integer
function M:__create_win_as_needed__(termmeta)
  local width = vim.o.columns - 2 ---@type integer
  local height = vim.o.lines - 3 ---@type integer
  local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
  local col = math.floor((vim.o.columns - width) / 2) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = dot.win.resolve_zindex(),
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

  local resize_result = nil ---@type dot.state.maximized.ResolveResizeResult|nil
  local winnr = _terminal_winnr ---@type integer|nil
  local bufnr = M.__create_buf_as_needed__(termmeta) ---@type integer
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    local bufnr_mask = create_mask_buf_as_needed() ---@type integer
    winnr = vim.api.nvim_open_win(bufnr_mask, true, wincfg)
    dot.win.set_type(winnr, dot.win.Types.TERMINAL)
    vim.api.nvim_win_set_buf(winnr, bufnr)

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
    ---@type dot.state.maximized.ResolveResizeResult
    resize_result = dot.state.maximized.resolve_resize_config(winnr, wincfg, { winblend = 0 })
    vim.api.nvim_win_set_config(winnr, resize_result.cfg)
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.wo[winnr].winfixbuf = true
  end

  vim.wo[winnr].winblend = resize_result and resize_result.winblend or 0
  vim.wo[winnr].winhighlight = TERMINAL_WIN_HIGHLIGHT
  dot.state.status.dirtier_termline:mark_dirty()

  termmeta.on_resized()
  return winnr
end

---@protected
---@param termmeta                      dot.module.term.IMeta
---@return nil
function M:__start__(termmeta)
  if termmeta.jobid == nil then
    local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
    local winnr = self:__create_win_as_needed__(termmeta) ---@type integer
    vim.api.nvim_tabpage_set_win(tabnr, winnr)
    self:__start_job__(termmeta)
  end
end

---@protected
---@param termmeta                      dot.module.term.IMeta
---@return nil
function M:__start_job__(termmeta)
  if termmeta.jobid ~= nil then
    return
  end

  local channelid = vim.fn.jobstart(termmeta.cmd, {
    cwd = termmeta.cwd,
    env = termmeta.env,
    pty = true,
    term = true,
    detach = false,
    on_exit = function(jobid, code, event)
      if code ~= 0 and code ~= 129 then
        ark.reporter.error({
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
        dot.term.event.on_closed(termmeta)
      end
    end,
  })
  termmeta.jobid = channelid
end

return M
