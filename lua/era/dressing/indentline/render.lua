---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.indentline.render" ---@type string

local parser = require("era.dressing.indentline.parser")

---@class era.dressing.indentline.render.IWhitespaceStyle
---@field public space                  string
---@field public multispace             string[]|nil
---@field public blank_space            string
---@field public blank_multispace       string[]|nil
---@field public tab_start              string|nil
---@field public tab_fill               string|nil
---@field public tab_end                string|nil

---@class era.dressing.indentline.render.IFrame
---@field public bufnr                  integer
---@field public changedtick            integer
---@field public start_row              integer
---@field public end_row                integer
---@field public leftcol                integer
---@field public is_current             boolean
---@field public indent_options         era.dressing.indentline.parser.IOptions
---@field public whitespace_style       era.dressing.indentline.render.IWhitespaceStyle
---@field public breakindent            boolean
---@field public filetype               string
---@field public levels                 table<integer, integer>
---@field public blank_rows             table<integer, true>
---@field public tab_whitespaces        table<integer, string>
---@field public whitespace_widths      table<integer, integer>
---@field public row_virt_texts         table<integer, string|false>
---@field public blank_virt_texts       table<integer, string>
---@field public plain_virt_texts       table<integer, string>
---@field public virt_texts             table<integer, string>
---@field public extmark_chunk          string[]|nil
---@field public extmark_options        table|nil

---@class era.dressing.indentline.render
local M = {}

local namespace = vim.api.nvim_create_namespace("era.dressing.indentline") ---@type integer
local frames = {} ---@type table<integer, era.dressing.indentline.render.IFrame>
local initialized = false ---@type boolean

---@param winnr                         integer
---@return integer
local function get_leftcol(winnr)
  return vim.api.nvim_win_call(winnr, function()
    return vim.fn.winsaveview().leftcol or 0
  end)
end

---@param value                         string
---@return string[]
local function split_chars(value)
  local chars = {} ---@type string[]
  local count = vim.fn.strchars(value) ---@type integer
  for index = 0, count - 1 do
    chars[#chars + 1] = vim.fn.strcharpart(value, index, 1)
  end
  return chars
end

---@param winnr                         integer
---@return era.dressing.indentline.render.IWhitespaceStyle
local function get_whitespace_style(winnr)
  return vim.api.nvim_win_call(winnr, function()
    if not vim.api.nvim_get_option_value("list", { win = 0 }) then
      return {
        space = " ",
        blank_space = " ",
        tab_start = " ",
        tab_fill = " ",
      }
    end

    local listchars = vim.opt_local.listchars:get() ---@type table<string, string>
    local tab_chars = split_chars(listchars.tab or "") ---@type string[]
    local leading_multispace = listchars.leadmultispace ---@type string|nil
    if leading_multispace == nil and listchars.lead == nil then
      leading_multispace = listchars.multispace
    end
    local multispace = split_chars(leading_multispace or "") ---@type string[]
    local blank_multispace = split_chars(listchars.multispace or "") ---@type string[]
    return {
      space = listchars.lead or listchars.space or " ",
      multispace = #multispace > 0 and multispace or nil,
      blank_space = listchars.trail or listchars.space or " ",
      blank_multispace = listchars.trail == nil and #blank_multispace > 0 and blank_multispace or nil,
      tab_start = tab_chars[1],
      tab_fill = tab_chars[2],
      tab_end = tab_chars[3],
    }
  end)
end

---@param frame                         era.dressing.indentline.render.IFrame
---@param bufnr                         integer
---@param changedtick                   integer
---@param start_row                     integer
---@param end_row                       integer
---@return boolean
local function content_matches(frame, bufnr, changedtick, start_row, end_row)
  return frame.bufnr == bufnr
    and frame.changedtick == changedtick
    and frame.start_row == start_row
    and frame.end_row == end_row
end

---@param bufnr                         integer
---@param lnum                          integer
---@param options                       era.dressing.indentline.parser.IOptions
---@return integer|nil
local function get_line_level(bufnr, lnum, options)
  if lnum <= 0 then
    return nil
  end
  local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] ---@type string|nil
  if line == nil then
    return nil
  end
  local level = parser.get_indent_level(line, options) ---@type integer
  return level
end

---@param bufnr                         integer
---@param lines                         string[]
---@param parse_start_row               integer
---@param parse_end_row                 integer
---@param line_count                    integer
---@param options                       era.dressing.indentline.parser.IOptions
---@return era.dressing.indentline.parser.IContext|nil
local function get_parse_context(bufnr, lines, parse_start_row, parse_end_row, line_count, options)
  local first_line = lines[1] ---@type string|nil
  local last_line = lines[#lines] ---@type string|nil
  local needs_previous = parse_start_row > 0 and first_line ~= nil and first_line:find("^%s*$") ~= nil ---@type boolean
  local needs_following = parse_end_row < line_count and last_line ~= nil and last_line:find("^%s*$") ~= nil ---@type boolean
  if not needs_previous and not needs_following then
    return nil
  end

  local previous_lnum = 0 ---@type integer
  local following_lnum = 0 ---@type integer
  vim.api.nvim_buf_call(bufnr, function()
    if needs_previous then
      previous_lnum = vim.fn.prevnonblank(parse_start_row)
    end
    if needs_following then
      following_lnum = vim.fn.nextnonblank(parse_end_row + 1)
    end
  end)

  return {
    previous_level = get_line_level(bufnr, previous_lnum, options),
    following_level = get_line_level(bufnr, following_lnum, options),
  }
end

---@param frame                         era.dressing.indentline.render.IFrame
---@param bufnr                         integer
---@param begin_row                     integer
---@param last_row                      integer
---@param config                        era.dressing.indentline.IConfig
---@return nil
local function draw_rows(frame, bufnr, begin_row, last_row, config)
  local row = begin_row ---@type integer
  local extmark_chunk = frame.extmark_chunk ---@type string[]|nil
  local extmark_options = frame.extmark_options ---@type table|nil
  local foldclosed = vim.fn.foldclosed
  local foldclosedend = vim.fn.foldclosedend
  local set_extmark = vim.api.nvim_buf_set_extmark
  while row <= last_row do
    local lnum = row + 1 ---@type integer
    if foldclosed(lnum) < 0 then
      local virt_text, hlgroup = M.make_virt_text(frame, row, config)
      if virt_text ~= nil and hlgroup ~= nil then
        if extmark_options == nil or extmark_chunk == nil then
          extmark_chunk = { virt_text, hlgroup }
          extmark_options = {
            ephemeral = true,
            virt_text = { extmark_chunk },
            virt_text_pos = "overlay",
            virt_text_repeat_linebreak = frame.breakindent,
            hl_mode = "combine",
            priority = config.priority,
          }
          frame.extmark_chunk = extmark_chunk
          frame.extmark_options = extmark_options
        else
          extmark_chunk[1] = virt_text
          extmark_chunk[2] = hlgroup
        end
        set_extmark(bufnr, namespace, row, 0, extmark_options)
      end
      row = row + 1
    else
      row = math.max(row + 1, foldclosedend(lnum))
    end
  end
end

---@param winnr                         integer
---@param bufnr                         integer
---@param start_row                     integer
---@param end_row                       integer
---@return era.dressing.indentline.render.IFrame|nil
---@return boolean redraw
function M.build_frame(winnr, bufnr, start_row, end_row)
  if
    not vim.api.nvim_win_is_valid(winnr)
    or not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.api.nvim_buf_is_loaded(bufnr)
  then
    return nil, false
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  start_row = math.max(0, math.min(start_row, line_count))
  end_row = math.max(start_row, math.min(end_row, line_count))

  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  local leftcol = get_leftcol(winnr) ---@type integer
  local cached = frames[winnr] ---@type era.dressing.indentline.render.IFrame|nil
  if cached ~= nil and content_matches(cached, bufnr, changedtick, start_row, end_row) then
    if cached.leftcol == leftcol then
      return cached, false
    end
    cached.leftcol = leftcol
    cached.row_virt_texts = {}
    return cached, true
  end

  local indent_options ---@type era.dressing.indentline.parser.IOptions
  local whitespace_style ---@type era.dressing.indentline.render.IWhitespaceStyle
  local breakindent ---@type boolean
  local filetype ---@type string
  local extmark_chunk = nil ---@type string[]|nil
  local extmark_options = nil ---@type table|nil
  if cached ~= nil and cached.bufnr == bufnr then
    indent_options = cached.indent_options
    whitespace_style = cached.whitespace_style
    breakindent = cached.breakindent
    filetype = cached.filetype
    extmark_chunk = cached.extmark_chunk
    extmark_options = cached.extmark_options
  else
    indent_options = parser.get_options(bufnr)
    whitespace_style = get_whitespace_style(winnr)
    breakindent = vim.api.nvim_get_option_value("breakindent", { win = winnr }) ---@type boolean
    filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  end
  local parse_start_row = math.max(0, start_row - 1) ---@type integer
  local parse_end_row = math.min(line_count, end_row + 1) ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, parse_start_row, parse_end_row, false) ---@type string[]
  local context = get_parse_context(bufnr, lines, parse_start_row, parse_end_row, line_count, indent_options)
  local result = parser.parse(lines, parse_start_row, indent_options, parser.is_dedent_scoped(filetype), context)
  local frame = {
    bufnr = bufnr,
    changedtick = changedtick,
    start_row = start_row,
    end_row = end_row,
    leftcol = leftcol,
    is_current = false,
    indent_options = indent_options,
    whitespace_style = whitespace_style,
    breakindent = breakindent,
    filetype = filetype,
    levels = result.levels,
    blank_rows = result.blank_rows,
    tab_whitespaces = result.tab_whitespaces,
    whitespace_widths = result.whitespace_widths,
    row_virt_texts = {},
    blank_virt_texts = {},
    plain_virt_texts = {},
    virt_texts = {},
    extmark_chunk = extmark_chunk,
    extmark_options = extmark_options,
  } ---@type era.dressing.indentline.render.IFrame
  frames[winnr] = frame
  return frame, true
end

---@param cells                         string[]
---@param start_col                     integer
---@param count                         integer
---@param space                         string
---@param multispace                    string[]|nil
---@return nil
local function fill_space_run(cells, start_col, count, space, multispace)
  if count > 1 and multispace ~= nil then
    local char_count = #multispace ---@type integer
    for offset = 1, count do
      cells[start_col + offset] = multispace[(offset - 1) % char_count + 1]
    end
    return
  end
  for offset = 1, count do
    cells[start_col + offset] = space
  end
end

---@param frame                         era.dressing.indentline.render.IFrame
---@param row                           integer
---@param config                        era.dressing.indentline.IConfig
---@return string|nil virt_text
---@return string|nil hlgroup
function M.make_virt_text(frame, row, config)
  local level = frame.levels[row] or 0 ---@type integer
  local shiftwidth = frame.indent_options.shiftwidth ---@type integer
  local target_width = level * shiftwidth ---@type integer
  if level < 1 or target_width <= frame.leftcol then
    return nil, nil
  end

  local cached = frame.row_virt_texts[row] ---@type string|false|nil
  if cached == false then
    return nil, nil
  end
  local virt_text = cached ---@type string|nil
  if virt_text == nil then
    local tab_whitespace = frame.tab_whitespaces[row] ---@type string|nil
    local whitespace_width = frame.whitespace_widths[row] or 0 ---@type integer
    local style = frame.whitespace_style ---@type era.dressing.indentline.render.IWhitespaceStyle
    local is_blank = frame.blank_rows[row] == true ---@type boolean
    local space = style.space ---@type string
    local multispace = style.multispace ---@type string[]|nil
    if is_blank then
      space = style.blank_space
      multispace = style.blank_multispace
    end
    if tab_whitespace ~= nil and style.tab_start == nil then
      -- Without listchars.tab, Neovim renders a tab as two cells (`^I`). A tabstop-width
      -- overlay would cover the following text, so preserve the native row instead.
      frame.row_virt_texts[row] = false
      return nil, nil
    end

    if tab_whitespace == nil and multispace == nil then
      local symbol = config.char .. string.rep(space, shiftwidth - 1) ---@type string
      local symbol_plain = config.char .. string.rep(" ", shiftwidth - 1) ---@type string
      local virt_texts = is_blank and frame.blank_virt_texts or frame.virt_texts ---@type table<integer, string>
      virt_text = virt_texts[level] or string.rep(symbol, level)
      virt_texts[level] = virt_text

      if space ~= " " and whitespace_width < target_width then
        if whitespace_width == 0 then
          virt_text = frame.plain_virt_texts[level] or string.rep(symbol_plain, level)
          frame.plain_virt_texts[level] = virt_text
        elseif whitespace_width % shiftwidth == 0 then
          local whitespace_level = whitespace_width / shiftwidth ---@type integer
          virt_text = string.rep(symbol, whitespace_level) .. string.rep(symbol_plain, level - whitespace_level)
        else
          local whitespace_level = math.floor(whitespace_width / shiftwidth) ---@type integer
          local remainder = whitespace_width % shiftwidth ---@type integer
          virt_text = string.rep(symbol, whitespace_level)
            .. config.char
            .. string.rep(space, remainder - 1)
            .. string.rep(" ", shiftwidth - remainder)
            .. string.rep(symbol_plain, level - whitespace_level - 1)
        end
      end
    else
      local cells = {} ---@type string[]
      local col = 0 ---@type integer
      if tab_whitespace == nil then
        fill_space_run(cells, 0, math.min(whitespace_width, target_width), space, multispace)
        col = whitespace_width
      else
        local index = 1 ---@type integer
        while index <= #tab_whitespace and col < target_width do
          if tab_whitespace:byte(index) ~= 9 then
            local run_end = index + 1 ---@type integer
            while run_end <= #tab_whitespace and tab_whitespace:byte(run_end) ~= 9 do
              run_end = run_end + 1
            end
            local run_length = run_end - index ---@type integer
            fill_space_run(cells, col, math.min(run_length, target_width - col), space, multispace)
            col = col + run_length
            index = run_end
          else
            local next_col = parser.get_next_tabstop(col, frame.indent_options) ---@type integer
            local tab_width = next_col - col ---@type integer
            local rendered_width = math.min(tab_width, target_width - col) ---@type integer
            for offset = 1, rendered_width do
              if offset == tab_width and style.tab_end ~= nil then
                cells[col + offset] = style.tab_end
              elseif offset == 1 then
                cells[col + offset] = style.tab_start
              else
                cells[col + offset] = style.tab_fill or " "
              end
            end
            col = next_col
            index = index + 1
          end
        end
      end

      for fill_col = math.min(col, target_width) + 1, target_width do
        cells[fill_col] = " "
      end
      -- Guides own shiftwidth boundaries; listchars fill the remaining real whitespace cells.
      for guide_col = 0, target_width - 1, shiftwidth do
        cells[guide_col + 1] = config.char
      end
      virt_text = table.concat(cells, "", 1, target_width)
    end

    if frame.leftcol > 0 then
      local byte_index = vim.str_byteindex(virt_text, "utf-32", frame.leftcol) ---@type integer
      virt_text = virt_text:sub(byte_index + 1)
    end
    frame.row_virt_texts[row] = virt_text
  end

  local hlgroup = config.highlights[level % #config.highlights + 1] ---@type string
  return virt_text, hlgroup
end

---@param winnr                         integer
---@param bufnr                         integer
---@param begin_row                     integer
---@param end_row                       integer
---@param end_col                       integer
---@param config                        era.dressing.indentline.IConfig
---@return nil
local function draw_range(winnr, bufnr, begin_row, end_row, end_col, config)
  local frame = frames[winnr] ---@type era.dressing.indentline.render.IFrame|nil
  if frame == nil or frame.bufnr ~= bufnr then
    return
  end

  local last_row = end_col == 0 and end_row - 1 or end_row ---@type integer
  begin_row = math.max(begin_row, frame.start_row)
  last_row = math.min(last_row, frame.end_row - 1)
  if begin_row > last_row then
    return
  end

  if frame.is_current then
    draw_rows(frame, bufnr, begin_row, last_row, config)
  else
    vim.api.nvim_win_call(winnr, function()
      draw_rows(frame, bufnr, begin_row, last_row, config)
    end)
  end
end

---@return nil
function M.invalidate()
  frames = {}
end

---@param winnr                         integer
---@return nil
function M.drop_window(winnr)
  frames[winnr] = nil
end

---@param config                        era.dressing.indentline.IConfig
---@param is_enabled                    fun(bufnr: integer): boolean
---@return nil
function M.setup(config, is_enabled)
  if initialized then
    return
  end
  initialized = true

  vim.api.nvim_set_decoration_provider(namespace, {
    on_win = function(_, winnr, bufnr, start_row, end_row)
      if not is_enabled(bufnr) then
        frames[winnr] = nil
        return false
      end
      local frame, rebuilt = M.build_frame(winnr, bufnr, start_row, end_row)
      if frame == nil then
        return false
      end
      frame.is_current = vim.api.nvim_get_current_win() == winnr
      if rebuilt then
        draw_range(winnr, bufnr, frame.start_row, frame.end_row, 0, config)
        return false
      end
      return true
    end,
    on_range = function(_, winnr, bufnr, begin_row, _, end_row, end_col)
      draw_range(winnr, bufnr, begin_row, end_row, end_col, config)
    end,
  })
end

return M
