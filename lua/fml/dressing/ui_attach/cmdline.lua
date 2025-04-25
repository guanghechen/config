local nsnrs = eve.constant.nsnr ---@type eve.constant.nsnr

---@class fml.dressing.ui_attach.cmdline.IState
---@field public pos                    integer
---@field public firstc                 string
---@field public prompt                 string
---@field public indent                 integer
---@field public level                  integer
---@field public icon                   string
---@field public type                   string
---@field public language               string|nil
---@field public concealable            boolean
---@field public first                  string
---@field public second                 string
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

local _cmdline_states = {} ---@type fml.dressing.ui_attach.cmdline.IState[]
-- stylua: ignore start
local _cmdline_title_map = {
  ["command"]         = string.format(" %s Command ", eve.icon.ui.Cmdline),
  ["command_help"]    = string.format(" %s Command | help ", eve.icon.ui.Cmdline),
  ["command_lua"]     = string.format(" %s Command | lua ", eve.icon.ui.Cmdline),
  ["search_forward"]  = string.format(" %s Search Forward ", eve.icon.ui.Search),
  ["search_backward"] = string.format(" %s Search Backward ", eve.icon.ui.Search),
}
local _cmdline_type_map = {
  ['command']         = string.format(" %s  ", eve.icon.ui.Cmdline),
  ["command_help"]    = string.format(" %s  ", ""),
  ["command_lua"]     = string.format(" %s  ", ""),
  ["search_forward"]  = string.format(" %s ", eve.icon.ui.SearchForward),
  ["search_backward"] = string.format(" %s ", eve.icon.ui.SearchBackward),
}
-- stylua: ignore end

---@class fml.dressing.ui_attach.cmdline
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.hide(task)
  local level = unpack(task.args) ---@type integer
  local state = _cmdline_states[level] ---@type fml.dressing.ui_attach.cmdline.IState|nil
  _cmdline_states[level] = nil

  if state ~= nil then
    local winnr = state.winnr ---@type integer|nil
    local bufnr = state.bufnr ---@type integer|nil
    state.winnr = nil
    state.bufnr = nil

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
function M.pos(task)
  local pos, level = unpack(task.args) ---@type integer
  local state = _cmdline_states[level] ---@type fml.dressing.ui_attach.cmdline.IState|nil
  if state ~= nil and state.pos ~= pos then
    state.pos = pos
    M._show(state)
  end
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.show(task)
  ---@diagnostic disable-next-line: unused-local
  local content, pos, firstc, prompt, indent, level = unpack(task.args)
  ---@cast content                      [integer, string][] -- [integer, text: string][]
  ---@cast pos                          integer             -- Cursor position in the command line (0-based)
  ---@cast firstc                       string              -- Command line prefix character, e.g., ':', '/', '?'
  ---@cast prompt                       string              -- Prompt text (optional)
  ---@cast indent                       integer             -- Indentation level (optional)
  ---@cast level                        integer             -- Nesting level, 0 means top level

  local typ = "command" ---@type string
  local language = nil ---@type string|nil
  if firstc == ":" then
    typ = "command" ---@type string
    language = "vim" ---@type string
  elseif firstc == "/" then
    typ = "search_forward" ---@type string
    language = "regex" ---@type string
  elseif firstc == "?" then
    typ = "search_backward" ---@type string
    language = "regex" ---@type string
  end

  local text = "" ---@type string
  for _, piece in ipairs(content) do
    text = text .. piece[2]
  end

  local concealable = false ---@type boolean
  local first = text ---@type string
  local second = "" ---@type string

  if typ == "command" then
    local f, s = text:match("^(%S+) (.*)$")
    if f == "lua" then
      typ = "command_lua" ---@type string
      language = "lua" ---@type string
      concealable = true
    elseif f == "h" or f == "he" or f == "hel" or f == "help" then
      typ = "command_help" ---@type string
      concealable = true
    end

    first = f and (f .. " ") or text ---@type string
    second = s or "" ---@type string
  end

  local icon = _cmdline_type_map[typ] ---@type string

  local state = _cmdline_states[level] ---@type fml.dressing.ui_attach.cmdline.IState|nil
  if state == nil then
    ---@type fml.dressing.ui_attach.cmdline.IState
    state = {
      pos = pos,
      firstc = firstc,
      prompt = prompt,
      indent = indent,
      level = level,
      icon = icon,
      type = typ,
      language = language,
      concealable = concealable,
      first = first,
      second = second,
      bufnr = nil,
      winnr = nil,
    }
    _cmdline_states[level] = state
  else
    state.pos = pos
    state.firstc = firstc
    state.prompt = prompt
    state.indent = indent
    state.level = level
    state.icon = icon
    state.type = typ
    state.language = language
    state.concealable = concealable
    state.first = first
    state.second = second
  end

  M._show(state)
end

---@param state                         fml.dressing.ui_attach.cmdline.IState
---@return nil
function M._show(state)
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
  local title = _cmdline_title_map[state.type] ---@type string

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = 1000 + state.level * 100,
    relative = "editor",
    width = width,
    height = 1,
    row = 3,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
    focusable = false,
  }

  local winnr = state.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
    state.winnr = winnr

    eve.win.set_type(winnr, eve.win.Types.CMDLINE)
    vim.w[winnr][eve.var.Names.WINLINE_DISABLED] = true
    vim.w[winnr][eve.var.Names.FLAG_SOURCEFILE] = false

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].wrap = false
    vim.wo[winnr].winhighlight = "Normal:f_uc_normal,FloatBorder:f_uc_border,CursorLine:f_uc_normal"
    vim.wo[winnr].winfixbuf = true
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.wo[winnr].winfixbuf = true
  end

  local hln_icon = "f_uc_icon_" .. state.type ---@type string
  local concealed = state.concealable and state.pos >= #state.first ---@type boolean
  local line = concealed and string.format("%s%s ", state.icon, state.second)
    or string.format("%s%s%s ", state.icon, state.first, state.second)

  vim.bo[bufnr].syntax = nil
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.cmdline, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { line })

  if state.language ~= nil and not vim.b[bufnr].ts_highlight then
    vim.bo[bufnr].syntax = state.language
  end

  vim.hl.range(bufnr, nsnrs.cmdline, hln_icon, { 0, 0 }, { 0, #state.icon })
  if not concealed then
    local offset = #state.icon ---@type integer
    vim.hl.range(bufnr, nsnrs.cmdline, hln_icon, { 0, offset }, { 0, offset + #state.first })
  end

  local pos = concealed and (state.pos + #state.icon - #state.first) or (state.pos + #state.icon)
  vim.api.nvim_win_set_cursor(winnr, { 1, pos })
  vim.api.nvim__redraw({ cursor = true, win = winnr, flush = true })
end

return M
