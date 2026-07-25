---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.ui_attach.cmdline" ---@type string

local states = require("era.m.ui_attach.state")

local nsnrs = dot.var.nsnr ---@type dot.var.nsnr

---@param entries                       era.m.ui_attach.IContent[]|nil
---@return string[]
---@return stl.t.IHighlight[]
local function parse_block_entries(entries)
  local lines = {} ---@type string[]
  local highlights = {} ---@type stl.t.IHighlight[]
  if type(entries) ~= "table" then
    return lines, highlights
  end

  for idx, entry in ipairs(entries) do
    local text = ""
    local offset = 0 ---@type integer
    if type(entry) == "table" then
      for _, chunk in ipairs(entry) do
        local chunk_text = ""
        local chunk_size = 0 ---@type integer
        if type(chunk) == "table" and chunk[2] ~= nil then
          chunk_text = tostring(chunk[2])
          chunk_size = #chunk_text
          local hlid = chunk[3]
          if type(hlid) == "number" and hlid > 0 and #chunk_text > 0 then
            local hlname = vim.fn.synIDattr(hlid, "name") ---@type string
            if #hlname > 0 then
              highlights[#highlights + 1] = {
                lnum = idx,
                coll = offset,
                colr = offset + chunk_size,
                hlname = hlname,
              }
            end
          end
        end
        text = text .. chunk_text
        offset = offset + chunk_size
      end
    end
    lines[#lines + 1] = text
  end

  return lines, highlights
end

-- stylua: ignore start
local _cmdline_title_map = {
  ["command"]         = string.format(" %s Command ", stl.icon.ui.Cmdline),
  ["command_help"]    = string.format(" %s Command | help ", stl.icon.ui.Cmdline),
  ["command_lua"]     = string.format(" %s Command | lua ", stl.icon.ui.Cmdline),
  ["search_forward"]  = string.format(" %s Search Forward ", stl.icon.ui.Search),
  ["search_backward"] = string.format(" %s Search Backward ", stl.icon.ui.Search),
}
local _cmdline_type_map = {
  ['command']         = string.format(" %s  ", stl.icon.ui.Cmdline),
  ["command_help"]    = string.format(" %s  ", ""),
  ["command_lua"]     = string.format(" %s  ", ""),
  ["confirm"]    = string.format(" %s  ", stl.icon.ui.Cmdline),
  ["search_forward"]  = string.format(" %s ", stl.icon.ui.SearchForward),
  ["search_backward"] = string.format(" %s ", stl.icon.ui.SearchBackward),
}
-- stylua: ignore end

---@class era.m.ui_attach.cmdline
local M = {}

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.hide(task)
  local level, abort = unpack(task.args) ---@type integer, boolean
  local state = states.cmdline[level] ---@type era.m.ui_attach.cmdline.IState|nil
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

  if abort then
    states.message.confirming_task = nil
  end

  vim.g.ui_cmdline_pos = nil
  local active = states.get_active_cmdline()
  if active == nil then
    states.message.confirming_task = nil
  elseif active.winnr ~= nil then
    M._update_cmdline_position(active, active.winnr)
  end
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.pos(task)
  local pos, level = unpack(task.args) ---@type integer
  local state = states.cmdline[level] ---@type era.m.ui_attach.cmdline.IState|nil
  if state ~= nil and state.pos ~= pos then
    state.pos = pos
    M._show(state)
    -- Update position for blink.cmp after position change
    if state.winnr and vim.api.nvim_win_is_valid(state.winnr) then
      M._update_cmdline_position(state, state.winnr)
    end
  end
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.show(task)
  ---@diagnostic disable-next-line: unused-local
  local content, pos, firstc, prompt, indent, level, hlid = unpack(task.args)
  ---@cast content                      era.m.ui_attach.IContent
  ---@cast pos                          integer             -- Cursor position in the command line (0-based)
  ---@cast firstc                       string              -- Command line prefix character, e.g., ':', '/', '?'
  ---@cast prompt                       string              -- Prompt text (optional)
  ---@cast indent                       integer             -- Indentation level (optional)
  ---@cast level                        integer             -- Nesting level, 1 means top level
  ---@cast hlid                         integer             -- hlgroup id

  local msg_show_task = states.message.confirming_task ---@type era.m.ui_attach.ITask|nil

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

  local state = states.cmdline[level] ---@type era.m.ui_attach.cmdline.IState|nil
  if state == nil then
    ---@type era.m.ui_attach.cmdline.IState
    state = {
      content = content,
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
      special = nil,
      bufnr = nil,
      winnr = nil,
    }
    states.cmdline[level] = state
  else
    state.content = content
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
    state.special = nil
  end

  if typ == "confirm" and msg_show_task ~= nil then
    states.message.confirming_task = nil
    M._show_confirm(state, msg_show_task)
  else
    M._show(state)
  end
end

---@class era.m.ui_attach.cmdline.IRender
---@field public line                   string
---@field public cursor_col             integer
---@field public content_offset         integer
---@field public concealed              boolean
---@field public highlights             stl.t.IHighlight[]

---@param state                         era.m.ui_attach.cmdline.IState
---@return era.m.ui_attach.cmdline.IRender
function M._resolve_render(state)
  local indent_text = string.rep(" ", state.indent) ---@type string
  local concealed = state.concealable and state.pos >= #state.first ---@type boolean
  local concealed_size = concealed and #state.first or 0 ---@type integer
  local content = state.first .. state.second ---@type string
  local visible_content = content:sub(concealed_size + 1) ---@type string
  local content_offset = #state.icon + #indent_text ---@type integer
  local highlights = {} ---@type stl.t.IHighlight[]
  local offset = 0 ---@type integer

  for _, chunk in ipairs(state.content) do
    local text = chunk[2] ---@type string
    local offset_next = offset + #text ---@type integer
    if offset_next > concealed_size then
      local hlname = vim.fn.synIDattr(chunk[3], "name") ---@type string
      if #hlname > 0 then
        highlights[#highlights + 1] = {
          lnum = 1,
          coll = content_offset + math.max(0, offset - concealed_size),
          colr = content_offset + offset_next - concealed_size,
          hlname = hlname,
        }
      end
    end
    offset = offset_next
  end

  return {
    line = state.icon .. indent_text .. visible_content .. " ",
    cursor_col = content_offset + math.max(0, state.pos - concealed_size),
    content_offset = content_offset,
    concealed = concealed,
    highlights = highlights,
  }
end

---@param state                         era.m.ui_attach.cmdline.IState
---@return nil
function M._show(state)
  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    state.bufnr = bufnr

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", stl.filetype.UX_CMDLINE, { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  end

  local width = math.min(math.floor(vim.o.columns * 0.8), 80) ---@type integer
  local title = _cmdline_title_map[state.type] ---@type string|[string, string][]
  if #state.prompt > 0 then
    local text = string.format(" %s %s ", stl.icon.ui.Edit, state.prompt) ---@type string
    local hlname = vim.fn.synIDattr(state.hlid, "name") ---@type string
    title = #hlname > 0 and { { text, hlname } } or text
  end

  ---@type vim.api.keyset.win_config
  local wincfg = {
    zindex = dot.var.zindex.CMDLINE + state.level * 100,
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

    vim.w[winnr].wintype = stl.e.WinTypeEnum.CMDLINE
    vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("list", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:f_uc_normal,FloatBorder:f_uc_border,CursorLine:f_uc_normal",
      { win = winnr, scope = "local" }
    )
    vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  else
    vim.api.nvim_set_option_value("winfixbuf", false, { win = winnr, scope = "local" })
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  end

  local hln_icon = "f_uc_icon_" .. state.type ---@type string
  local render = M._resolve_render(state)

  vim.api.nvim_set_option_value("syntax", nil, { buf = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.cmdline, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { render.line })

  if state.language ~= nil and not vim.b[bufnr].ts_highlight then
    vim.api.nvim_set_option_value("syntax", state.language, { buf = bufnr })
  end

  vim.hl.range(bufnr, nsnrs.cmdline, hln_icon, { 0, 0 }, { 0, #state.icon })
  if not render.concealed then
    local offset = render.content_offset ---@type integer
    vim.hl.range(bufnr, nsnrs.cmdline, hln_icon, { 0, offset }, { 0, offset + #state.first })
  end
  for _, hl in ipairs(render.highlights) do
    vim.hl.range(bufnr, nsnrs.cmdline, hl.hlname, { 0, hl.coll }, { 0, hl.colr })
  end
  if state.special ~= nil then
    vim.api.nvim_buf_set_extmark(bufnr, nsnrs.cmdline, 0, render.cursor_col, {
      virt_text = { { state.special.c, "SpecialKey" } },
      virt_text_pos = state.special.shift and "inline" or "overlay",
      hl_mode = "combine",
    })
  end

  vim.api.nvim_win_set_cursor(winnr, { 1, render.cursor_col })
  vim.api.nvim__redraw({ cursor = true, win = winnr, flush = true })

  -- Refresh the cmdline position for blink.cmp compatibility
  M._update_cmdline_position(state, winnr)
end

---@param state                         era.m.ui_attach.cmdline.IState
---@param winnr                         integer
---@return nil
function M._update_cmdline_position(state, winnr)
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return
  end

  local concealed = state.concealable and state.pos >= #state.first ---@type boolean
  local concealed_size = concealed and #state.first or 0 ---@type integer
  local buffer_cursor_col = #state.icon + state.indent + math.max(0, state.pos - concealed_size)
  local screenpos = vim.fn.screenpos(winnr, 1, buffer_cursor_col + 1)
  if screenpos.row < 1 or screenpos.col < 1 then
    vim.g.ui_cmdline_pos = nil
    return
  end

  local content = state.first .. state.second ---@type string
  local prefix_width = vim.fn.strdisplaywidth(content:sub(1, state.pos)) ---@type integer
  local content_col = screenpos.col - 1 - prefix_width ---@type integer

  -- blink.cmp expects a 1-indexed row and 0-indexed column for the original
  -- cmdline content; completion offsets are applied by the consumer.
  vim.g.ui_cmdline_pos = {
    screenpos.row,
    content_col,
  }
end

---@param block                         era.m.ui_attach.cmdline_block.IState
---@return nil
function M._render_block(block)
  if #block.lines < 1 then
    return
  end

  local bufnr = block.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    block.bufnr = bufnr

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", stl.filetype.UX_CMDLINE, { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
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
    zindex = dot.var.zindex.CMDLINE_BLOCK,
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

    vim.w[winnr].wintype = stl.e.WinTypeEnum.CMDLINE
    vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("list", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("relativenumber", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("wrap", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:f_uc_normal,FloatBorder:f_uc_border,CursorLine:f_uc_normal",
      { win = winnr, scope = "local" }
    )
  else
    vim.api.nvim_win_set_config(winnr, wincfg)
  end

  local padded = {} ---@type string[]
  for _, line in ipairs(block.lines) do
    padded[#padded + 1] = stl.string.pad_end(line, width, " ")
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

---@param state                         era.m.ui_attach.cmdline.IState
---@param msg_show_task                 era.m.ui_attach.ITask
---@return nil
function M._show_confirm(state, msg_show_task)
  local bufnr = state.bufnr ---@type integer|nil
  if bufnr == nil or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true) ---@type integer
    state.bufnr = bufnr

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
    vim.api.nvim_set_option_value("filetype", stl.filetype.UX_CMDLINE, { buf = bufnr })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  end

  local buttons = {} ---@type string[]
  for token in vim.trim(state.prompt):gsub(":$", ""):gmatch("%s*([^,]+)%s*,?") do
    local button = string.format(" %s ", token) ---@type string
    table.insert(buttons, button)
  end
  local buttons_line = "  " .. table.concat(buttons, "  ") .. "  " ---@type string
  local button_line_width = vim.api.nvim_strwidth(buttons_line) ---@type integer

  local message = "" ---@type string
  local highlights = {} ---@type stl.t.IHighlight[]

  ---! resolve the lines and highlights
  do
    local lnum, col_offset = 1, 0 ---@type integer, integer
    local content = msg_show_task.args[2] ---@type era.m.ui_attach.IContent
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
          ---@type stl.t.IHighlight
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
      ---@type stl.t.IHighlight
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
    zindex = dot.var.zindex.CMDLINE + state.level * 100,
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

    vim.w[winnr].wintype = stl.e.WinTypeEnum.CMDLINE
    vim.w[winnr][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("cursorline", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("list", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("number", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value("wrap", true, { win = winnr, scope = "local" })
    vim.api.nvim_set_option_value(
      "winhighlight",
      "Normal:f_uc_normal,FloatBorder:f_uc_border,CursorLine:f_uc_normal",
      { win = winnr, scope = "local" }
    )
    vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  else
    vim.api.nvim_set_option_value("winfixbuf", false, { win = winnr, scope = "local" })
    vim.api.nvim_win_set_buf(winnr, bufnr)
    vim.api.nvim_win_set_config(winnr, wincfg)
    vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr, scope = "local" })
  end

  vim.api.nvim_set_option_value("syntax", nil, { buf = bufnr })
  vim.api.nvim_buf_clear_namespace(bufnr, nsnrs.cmdline, 0, -1)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  for _, hl in ipairs(highlights) do
    local row = hl.lnum - 1 ---@type integer
    vim.hl.range(bufnr, nsnrs.cmdline, hl.hlname, { row, hl.coll }, { row, hl.colr })
  end

  if state.language ~= nil and not vim.b[bufnr].ts_highlight then
    vim.api.nvim_set_option_value("syntax", "markdown", { buf = bufnr })
  end
  vim.api.nvim__redraw({ cursor = false, win = winnr, flush = true })

  -- Set the cmdline position for blink.cmp compatibility (confirm dialog)
  M._update_cmdline_position(state, winnr)
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.special_char(task)
  local c, shift, level = unpack(task.args)
  ---@cast c                            string
  ---@cast shift                        boolean
  ---@cast level                        integer
  local state = states.cmdline[level] ---@type era.m.ui_attach.cmdline.IState|nil
  if state == nil then
    return
  end

  state.special = { c = c, shift = shift }
  M._show(state)
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.block_show(task)
  local entries = unpack(task.args)
  ---@cast entries                      era.m.ui_attach.IContent[]|nil
  local lines, highlights = parse_block_entries(entries)
  local block = states.cmdline_block
  block.lines = lines
  block.highlights = highlights
  M._render_block(block)
end

---@param task                          era.m.ui_attach.ITask
---@return nil
function M.block_append(task)
  local entry = unpack(task.args)
  ---@cast entry                        era.m.ui_attach.IContent|nil
  local lines, highlights = parse_block_entries(entry ~= nil and { entry } or nil)
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

---@param task                          era.m.ui_attach.ITask
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
