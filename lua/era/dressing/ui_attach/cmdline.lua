local states = require("era.dressing.ui_attach.state")

local nsnrs = ark.var.nsnr ---@type ark.var.nsnr

---@param entries                       table[]|nil
---@return string[]
---@return ark.t.IHighlight[]
local function parse_block_entries(entries)
  local lines = {} ---@type string[]
  local highlights = {} ---@type ark.t.IHighlight[]
  if type(entries) ~= "table" then
    return lines, highlights
  end

  for idx, entry in ipairs(entries) do
    local text = ""
    local offset = 0 ---@type integer
    if type(entry) == "table" then
      for _, chunk in ipairs(entry) do
        local chunk_text = ""
        local chunk_width = 0 ---@type integer
        if type(chunk) == "table" and chunk[2] ~= nil then
          chunk_text = tostring(chunk[2])
          chunk_width = vim.fn.strdisplaywidth(chunk_text)
          local hlid = chunk[1]
          if type(hlid) == "number" and hlid > 0 and #chunk_text > 0 then
            local hlname = vim.fn.synIDattr(hlid, "name") ---@type string
            if #hlname > 0 then
              highlights[#highlights + 1] = {
                lnum = idx,
                coll = offset,
                colr = offset + chunk_width,
                hlname = hlname,
              }
            end
          end
        end
        text = text .. chunk_text
        offset = offset + chunk_width
      end
    end
    lines[#lines + 1] = text
  end

  return lines, highlights
end

-- stylua: ignore start
local _cmdline_title_map = {
  ["command"]         = string.format(" %s Command ", ark.icon.ui.Cmdline),
  ["command_help"]    = string.format(" %s Command | help ", ark.icon.ui.Cmdline),
  ["command_lua"]     = string.format(" %s Command | lua ", ark.icon.ui.Cmdline),
  ["search_forward"]  = string.format(" %s Search Forward ", ark.icon.ui.Search),
  ["search_backward"] = string.format(" %s Search Backward ", ark.icon.ui.Search),
}
local _cmdline_type_map = {
  ['command']         = string.format(" %s  ", ark.icon.ui.Cmdline),
  ["command_help"]    = string.format(" %s  ", ""),
  ["command_lua"]     = string.format(" %s  ", ""),
  ["confirm"]    = string.format(" %s  ", ark.icon.ui.Cmdline),
  ["search_forward"]  = string.format(" %s ", ark.icon.ui.SearchForward),
  ["search_backward"] = string.format(" %s ", ark.icon.ui.SearchBackward),
}
-- stylua: ignore end

---@class era.dressing.ui_attach.cmdline
local M = {}

---@param task                          era.dressing.ui_attach.ITask
---@return nil
function M.hide(task)
  local level = unpack(task.args) ---@type integer
  local state = states.cmdline[level] ---@type era.dressing.ui_attach.cmdline.IState|nil
  states.cmdline[level] = nil

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

  -- Clear cmdline position when hiding (similar to noice.nvim behavior)
  -- Only clear if this is the top-level cmdline (level 0)
  if level == 0 then
    vim.g.ui_cmdline_pos = nil
  end
end

---@param task                          era.dressing.ui_attach.ITask
---@return nil
function M.pos(task)
  local pos, level = unpack(task.args) ---@type integer
  local state = states.cmdline[level] ---@type era.dressing.ui_attach.cmdline.IState|nil
  if state ~= nil and state.pos ~= pos then
    state.pos = pos
    M._show(state)
    -- Update position for blink.cmp after position change
    if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
      M._update_cmdline_position(state, state.winnr)
    end
  end
end

---@param task                          era.dressing.ui_attach.ITask
---@return nil
function M.show(task)
  ---@diagnostic disable-next-line: unused-local
  local content, pos, firstc, prompt, indent, level, hlid = unpack(task.args)
  ---@cast content                      [integer, string][] -- [integer, text: string][]
  ---@cast pos                          integer             -- Cursor position in the command line (0-based)
  ---@cast firstc                       string              -- Command line prefix character, e.g., ':', '/', '?'
  ---@cast prompt                       string              -- Prompt text (optional)
  ---@cast indent                       integer             -- Indentation level (optional)
  ---@cast level                        integer             -- Nesting level, 0 means top level
  ---@cast hlid                         integer             -- hlgroup id

  local msg_show_task = states.message.confirming_task ---@type era.dressing.ui_attach.ITask|nil
  prompt = vim.trim(prompt):gsub(":$", "") ---@type string

  local typ = states.message.confirming_task ~= nil and "confirm" or "command" ---@type string
  local language = nil ---@type string|nil
  if firstc == ":" then
    typ = "command" ---@type string
    language = "vim" ---@type string
    states.message.confirming_task = nil
  elseif firstc == "/" then
    typ = "search_forward" ---@type string
    language = "regex" ---@type string
    states.message.confirming_task = nil
  elseif firstc == "?" then
    typ = "search_backward" ---@type string
    language = "regex" ---@type string
    states.message.confirming_task = nil
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

  local state = states.cmdline[level] ---@type era.dressing.ui_attach.cmdline.IState|nil
  if state == nil then
    ---@type era.dressing.ui_attach.cmdline.IState
    state = {
      pos = pos,
      firstc = firstc,
      prompt = prompt,
      indent = indent,
      level = level,
      hlid = hlid,
      icon = icon,
      type = typ,
      language = language,
      concealable = concealable,
      first = first,
      second = second,
      bufnr = nil,
      winnr = nil,
    }
    states.cmdline[level] = state
  else
    state.pos = pos
    state.firstc = firstc
    state.prompt = prompt
    state.indent = indent
    state.level = level
    state.hlid = hlid
    state.icon = icon
    state.type = typ
    state.language = language
    state.concealable = concealable
    state.first = first
    state.second = second
  end

  if typ == "confirm" and msg_show_task ~= nil then
    M._show_confirm(state, msg_show_task)
  else
    M._show(state)
  end
end

---@param state                         era.dressing.ui_attach.cmdline.IState
---@return nil
function M._show(state)
  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    state.bufnr = bufnr

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = ark.filetype.UX_CMDLINE
    vim.bo[bufnr].swapfile = false
  end

  local width = math.min(math.floor(vim.o.columns * 0.8), 80) ---@type integer
  local title = #state.prompt > 0 and string.format(" %s %s ", ark.icon.ui.Edit, state.prompt)
    or _cmdline_title_map[state.type] ---@type string

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = ark.var.zindex.CMDLINE + state.level * 100,
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

    dot.win.set_type(winnr, ark.vim.win.Types.CMDLINE)
    vim.w[winnr][ark.var.N_WINLINE_DISABLED] = true

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
  local hln_basic = vim.fn.synIDattr(state.hlid, "name") ---@type string

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
  vim.hl.range(bufnr, nsnrs.cmdline, hln_basic, { 0, #state.icon }, { 0, -1 })
  if not concealed then
    local offset = #state.icon ---@type integer
    vim.hl.range(bufnr, nsnrs.cmdline, hln_icon, { 0, offset }, { 0, offset + #state.first })
  end

  local pos = concealed and (state.pos + #state.icon - #state.first) or (state.pos + #state.icon)
  vim.api.nvim_win_set_cursor(winnr, { 1, pos })
  vim.api.nvim__redraw({ cursor = true, win = winnr, flush = true })

  -- Refresh the cmdline position for blink.cmp compatibility
  M._update_cmdline_position(state, winnr)
end

---@param state                         era.dressing.ui_attach.cmdline.IState
---@param winnr                         integer
---@return nil
function M._update_cmdline_position(state, winnr)
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  -- Get the window configuration to determine the screen position
  local wincfg = vim.api.nvim_win_get_config(winnr) ---@type vim.api.keyset.win_config

  -- Calculate the screen position of the cmdline content
  -- The content starts after the icon and any concealed portions
  local icon_width = vim.api.nvim_strwidth(state.icon) ---@type integer
  local first_width = vim.api.nvim_strwidth(state.first) ---@type integer
  local concealed_prefix = state.concealable and state.pos >= #state.first ---@type boolean

  local content_start_col = icon_width ---@type integer
  if not concealed_prefix then
    -- When not concealed, content starts after icon + first part (command verb)
    content_start_col = icon_width + first_width
  end

  -- Set vim.g.ui_cmdline_pos for blink.cmp to use
  -- blink.cmp expects 0-indexed coordinates
  -- Position the popup below the cmdline window with proper spacing:
  -- - Add window height (1 for regular cmdline, variable for confirm)
  -- - Add 2 for rounded border (top + bottom)
  -- - No additional spacing for closer positioning
  local popup_row = wincfg.row + wincfg.height + 2 ---@type integer
  vim.g.ui_cmdline_pos = {
    popup_row, -- position popup below the cmdline UI with spacing
    wincfg.col + content_start_col, -- col + offset to the content start (display width aware)
  }
end

---@param block                         era.dressing.ui_attach.cmdline_block.IState
---@return nil
function M._render_block(block)
  if #block.lines < 1 then
    return
  end

  local bufnr = block.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    block.bufnr = bufnr

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = ark.filetype.UX_CMDLINE
    vim.bo[bufnr].swapfile = false
  end

  local width = 0 ---@type integer
  for _, line in ipairs(block.lines) do
    local w = vim.api.nvim_strwidth(line)
    width = w > width and w or width
  end
  width = math.max(20, math.min(width, math.floor(vim.o.columns * 0.9)))

  local height = math.min(#block.lines, math.max(1, math.floor(vim.o.lines * 0.6))) ---@type integer
  local row = math.max(0, math.floor((vim.o.lines - height) / 2)) ---@type integer
  local col = math.max(0, math.floor((vim.o.columns - width) / 2)) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = ark.var.zindex.CMDLINE_BLOCK,
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Command Window ",
    title_pos = "center",
    focusable = false,
  }

  local winnr = block.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
    block.winnr = winnr

    dot.win.set_type(winnr, ark.vim.win.Types.CMDLINE)
    vim.w[winnr][ark.var.N_WINLINE_DISABLED] = true

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].relativenumber = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].wrap = false
    vim.wo[winnr].winhighlight = "Normal:f_uc_normal,FloatBorder:f_uc_border,CursorLine:f_uc_normal"
  else
    vim.api.nvim_win_set_config(winnr, wincfg)
  end

  local padded = {} ---@type string[]
  for _, line in ipairs(block.lines) do
    padded[#padded + 1] = ark.string.pad_end(line, width, " ")
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, padded)
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.cmdline, 0, -1)

  local total_lines = #block.lines ---@type integer
  for _, hl in ipairs(block.highlights) do
    local row_idx = hl.lnum - 1
    if row_idx >= 0 and row_idx < total_lines then
      vim.hl.range(bufnr, nsnrs.cmdline, hl.hlname, { row_idx, hl.coll }, { row_idx, hl.colr })
    end
  end

  vim.api.nvim__redraw({ win = winnr, flush = true })
end

---@param state                         era.dressing.ui_attach.cmdline.IState
---@param msg_show_task                 era.dressing.ui_attach.ITask
---@return nil
function M._show_confirm(state, msg_show_task)
  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    state.bufnr = bufnr

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buflisted = false
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].filetype = ark.filetype.UX_CMDLINE
    vim.bo[bufnr].swapfile = false
  end

  local buttons = {} ---@type string[]
  for token in vim.trim(state.prompt):gsub(":$", ""):gmatch("%s*([^,]+)%s*,?") do
    local button = string.format(" %s ", token) ---@type string
    table.insert(buttons, button)
  end
  local buttons_line = "  " .. table.concat(buttons, "  ") .. "  " ---@type string
  local button_line_width = vim.api.nvim_strwidth(buttons_line) ---@type integer

  local message = "" ---@type string
  local highlights = {} ---@type ark.t.IHighlight[]

  ---! resolve the lines and highlights
  do
    local lnum, col_offset = 1, 0 ---@type integer, integer
    local content = msg_show_task.args[2] ---@type [integer, string, integer][]
    for index, item in ipairs(content) do
      local _, text, hlid = unpack(item) ---@type integer, string, integer
      if index == 1 then
        text = text:match("^%s*(.*)") ---@type string
      elseif index == #content then
        text = text:match("(.*%S)") ---@type string
      end

      message = message .. text ---@type string
      local hlname = vim.fn.synIDattr(hlid, "name") ---@type string
      local lines = vim.split(text, "\n", { plain = true }) ---@type string[]
      for i, line in ipairs(lines) do
        if i > 1 then
          lnum = lnum + 1
          col_offset = 0
        end
        if #line > 0 then
          ---@type ark.t.IHighlight
          local highlight = {
            lnum = lnum,
            coll = col_offset,
            colr = col_offset + #line,
            hlname = hlname,
          }
          highlights[#highlights + 1] = highlight
          col_offset = col_offset + #line
        end
      end
    end
  end

  local message_width = 0 ---@type integer
  local lines = vim.split(message, "\n", { plain = true }) ---@type string[]

  do
    for _, line in ipairs(lines) do
      local width = vim.api.nvim_strwidth(line) ---@type integer
      message_width = message_width < width and width or message_width ---@type integer
    end
    message_width = message_width + 2 ---@type integer
    local message_padding_width = math.floor((button_line_width - message_width) / 2) ---@type integer
    message_padding_width = math.max(1, message_padding_width)
    local message_padding = string.rep(" ", message_padding_width) ---@type string

    for index, line in ipairs(lines) do
      lines[index] = string.format("%s%s", message_padding, line) ---@type string
    end

    local buttons_padding_width = 0 ---@type integer
    if button_line_width < message_width then
      buttons_padding_width = math.floor((message_width - button_line_width) / 2) ---@type integer
      local buttons_padding = string.rep(" ", buttons_padding_width) ---@type string
      buttons_line = string.format("%s%s", buttons_padding, buttons_line)
    end

    for _, hl in ipairs(highlights) do
      hl.coll = hl.coll + message_padding_width
      hl.colr = hl.colr + message_padding_width
    end

    local lnum = #lines + 1 ---@type integer
    local buttons_offset = buttons_padding_width + 2 ---@type integer
    for index, button in ipairs(buttons) do
      local w = vim.api.nvim_strwidth(button) ---@type integer
      ---@type ark.t.IHighlight
      local highlight = {
        lnum = lnum,
        coll = buttons_offset,
        colr = buttons_offset + w,
        hlname = index == 1 and "f_uc_option_current" or "f_uc_option",
      }
      table.insert(highlights, highlight)
      buttons_offset = buttons_offset + w + 2
    end

    lines[#lines + 1] = buttons_line
  end

  local height = math.min(math.floor(vim.o.lines * 0.8), #lines) ---@type integer
  local width = math.max(button_line_width, message_width) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = ark.var.zindex.CMDLINE + state.level * 100,
    relative = "editor",
    width = width,
    height = height,
    row = 3,
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    title = " Confirm ",
    title_pos = "center",
    border = "rounded",
    focusable = false,
  }

  local winnr = state.winnr ---@type integer|nil
  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    wincfg.noautocmd = true
    winnr = vim.api.nvim_open_win(bufnr, false, wincfg)
    state.winnr = winnr

    dot.win.set_type(winnr, ark.vim.win.Types.CMDLINE)
    vim.w[winnr][ark.var.N_WINLINE_DISABLED] = true

    vim.wo[winnr].cursorline = false
    vim.wo[winnr].list = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].spell = false
    vim.wo[winnr].wrap = true
    vim.wo[winnr].winhighlight = "Normal:f_uc_normal,FloatBorder:f_uc_border,CursorLine:f_uc_normal"
    vim.wo[winnr].winfixbuf = true
  else
    vim.wo[winnr].winfixbuf = false
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.wo[winnr].winfixbuf = true
  end

  vim.bo[bufnr].syntax = nil
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.cmdline, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  for _, hl in ipairs(highlights) do
    local row = hl.lnum - 1 ---@type integer
    vim.hl.range(bufnr, nsnrs.cmdline, hl.hlname, { row, hl.coll }, { row, hl.colr })
  end

  if state.language ~= nil and not vim.b[bufnr].ts_highlight then
    vim.bo[bufnr].syntax = "markdown"
  end
  vim.api.nvim__redraw({ cursor = false, win = winnr, flush = true })

  -- Set the cmdline position for blink.cmp compatibility (confirm dialog)
  M._update_cmdline_position(state, winnr)
end

---@param task                          era.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.special_char(task) end

---@param task                          era.dressing.ui_attach.ITask
---@return nil
function M.block_show(task)
  local entries = unpack(task.args)
  ---@cast entries                      table[]|nil
  local lines, highlights = parse_block_entries(entries)
  local block = states.cmdline_block
  block.lines = lines
  block.highlights = highlights
  M._render_block(block)
end

---@param task                          era.dressing.ui_attach.ITask
---@return nil
function M.block_append(task)
  local entries = unpack(task.args)
  ---@cast entries                      table[]|nil
  local lines, highlights = parse_block_entries(entries)
  local block = states.cmdline_block
  local base = #block.lines
  for _, line in ipairs(lines) do
    block.lines[#block.lines + 1] = line
  end
  for _, hl in ipairs(highlights) do
    hl.lnum = hl.lnum + base
    block.highlights[#block.highlights + 1] = hl
  end
  M._render_block(block)
end

---@param task                          era.dressing.ui_attach.ITask
---@return nil
---@diagnostic disable-next-line: unused-local
function M.block_hide(task)
  local block = states.cmdline_block
  block.lines = {}
  block.highlights = {}

  local winnr = block.winnr ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    vim.api.nvim_win_close(winnr, true)
  end
  local bufnr = block.bufnr ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end
  block.winnr = nil
  block.bufnr = nil
end

return M
