local nsnrs = eve.constant.nsnr ---@type eve.constant.nsnr

---@class fml.dressing.ui_attach.cmdline.IState
---@field public content                [integer, string][]
---@field public pos                    integer
---@field public firstc                 string
---@field public prompt                 string
---@field public indent                 integer
---@field public level                  integer
---@field public type                   string
---@field public prefix                 string
---@field public offset                 integer
---@field public bufnr                  integer|nil
---@field public winnr                  integer|nil

local states = {} ---@type fml.dressing.ui_attach.cmdline.IState[]

---@class fml.dressing.ui_attach.cmdline
local M = {}

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.hide(task)
  local level = unpack(task.args) ---@type integer
  local state = states[level] ---@type fml.dressing.ui_attach.cmdline.IState|nil
  states[level] = nil

  if state ~= nil then
    local winnr = state.winnr ---@type integer|nil
    local bufnr = state.bufnr ---@type integer|nil
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
  local state = states[level] ---@type fml.dressing.ui_attach.cmdline.IState|nil
  if state ~= nil and state.pos ~= pos then
    state.pos = pos

    local winnr = state.winnr ---@type integer|nil
    if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
      vim.api.nvim_win_set_cursor(state.winnr, { 1, pos + state.offset })
      vim.api.nvim__redraw({ cursor = true, win = winnr, flush = true })
    else
      M._show(state)
    end
  end
end

---@param task                          fml.dressing.ui_attach.ITask
---@return nil
function M.show(task)
  ---@diagnostic disable-next-line: unused-local
  local content, pos, firstc, prompt, indent, level, type = unpack(task.args)
  ---@cast content                      [integer, string][] -- [integer, text: string][]
  ---@cast pos                          integer             -- Cursor position in the command line (0-based)
  ---@cast firstc                       string              -- Command line prefix character, e.g., ':', '/', '?'
  ---@cast prompt                       string              -- Prompt text (optional)
  ---@cast indent                       integer             -- Indentation level (optional)
  ---@cast level                        integer             -- Nesting level, 0 means top level
  ---@cast type                         string              -- Command line type, e.g., 'cmd', 'search_forward', 'search_backward', etc.

  local prefix = string.format(" %s  ", eve.icon.ui.Cmdline) ---@type string
  local offset = #prefix ---@type integer

  local state = states[level] ---@type fml.dressing.ui_attach.cmdline.IState|nil
  if state == nil then
    ---@type fml.dressing.ui_attach.cmdline.IState
    state = {
      content = content,
      pos = pos,
      firstc = firstc,
      prompt = prompt,
      indent = indent,
      level = level,
      type = type,
      prefix = prefix,
      offset = offset,
      bufnr = nil,
      winnr = nil,
    }
    states[level] = state
  else
    state.content = content
    state.pos = pos
    state.firstc = firstc
    state.prompt = prompt
    state.indent = indent
    state.level = level
    state.type = type
    state.prefix = prefix
    state.offset = offset
  end

  M._show(state)
end

---@param state                         fml.dressing.ui_attach.cmdline.IState
---@return nil
function M._show(state)
  local content = state.content ---@type [integer, string][]
  local prompt = state.prompt ---@type string
  local pos = state.pos ---@type integer

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
    title = string.format(" %s  %s ", eve.icon.ui.Cmdline, #prompt > 0 and prompt or "Cmdline"),
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

  local line = state.prefix ---@type string
  local offset = state.offset ---@type integer
  for _, piece in ipairs(content) do
    line = line .. piece[2]
  end
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.attach, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { line .. " " })

  vim.api.nvim_win_set_cursor(winnr, { 1, pos + offset })
  vim.api.nvim__redraw({ cursor = true, win = winnr, flush = true })
end

return M
