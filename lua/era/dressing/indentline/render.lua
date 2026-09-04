---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.indentline.render" ---@type string

local parser = require("era.dressing.indentline.parser")

---@class era.dressing.indentline.render.IFrame
---@field public bufnr                  integer
---@field public changedtick            integer
---@field public start_row              integer
---@field public end_row                integer
---@field public leftcol                integer
---@field public shiftwidth             integer
---@field public space                  string
---@field public breakindent            boolean
---@field public filetype               string
---@field public levels                 table<integer, integer>
---@field public whitespace_lengths     table<integer, integer>
---@field public virt_texts             table<integer, string>

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

---@param winnr                         integer
---@return string
local function get_space(winnr)
  local listchars = vim.api.nvim_get_option_value("listchars", { win = winnr }) ---@type string
  local space = listchars:match("space:([^,]*)") ---@type string|nil
  if space == nil or space == "" then
    return " "
  end
  return space:sub(1, 1 + vim.str_utf_end(space, 1))
end

---@param frame                         era.dressing.indentline.render.IFrame
---@param bufnr                         integer
---@param changedtick                   integer
---@param start_row                     integer
---@param end_row                       integer
---@param leftcol                       integer
---@param shiftwidth                    integer
---@param space                         string
---@param breakindent                   boolean
---@param filetype                      string
---@return boolean
local function frame_matches(
  frame,
  bufnr,
  changedtick,
  start_row,
  end_row,
  leftcol,
  shiftwidth,
  space,
  breakindent,
  filetype
)
  return frame.bufnr == bufnr
    and frame.changedtick == changedtick
    and frame.start_row == start_row
    and frame.end_row == end_row
    and frame.leftcol == leftcol
    and frame.shiftwidth == shiftwidth
    and frame.space == space
    and frame.breakindent == breakindent
    and frame.filetype == filetype
end

---@param winnr                         integer
---@param bufnr                         integer
---@param start_row                     integer
---@param end_row                       integer
---@return era.dressing.indentline.render.IFrame|nil
function M.build_frame(winnr, bufnr, start_row, end_row)
  if
    not vim.api.nvim_win_is_valid(winnr)
    or not vim.api.nvim_buf_is_valid(bufnr)
    or not vim.api.nvim_buf_is_loaded(bufnr)
  then
    return nil
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  start_row = math.max(0, math.min(start_row, line_count))
  end_row = math.max(start_row, math.min(end_row, line_count))

  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  local leftcol = get_leftcol(winnr) ---@type integer
  local shiftwidth = parser.get_shiftwidth(bufnr) ---@type integer
  local space = get_space(winnr) ---@type string
  local breakindent = vim.api.nvim_get_option_value("breakindent", { win = winnr }) ---@type boolean
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr }) ---@type string
  local cached = frames[winnr] ---@type era.dressing.indentline.render.IFrame|nil
  if
    cached ~= nil
    and frame_matches(cached, bufnr, changedtick, start_row, end_row, leftcol, shiftwidth, space, breakindent, filetype)
  then
    return cached
  end

  local parse_start_row = math.max(0, start_row - 1) ---@type integer
  local parse_end_row = math.min(line_count, end_row + 1) ---@type integer
  local lines = vim.api.nvim_buf_get_lines(bufnr, parse_start_row, parse_end_row, false) ---@type string[]
  local result = parser.parse(lines, parse_start_row, shiftwidth, parser.is_dedent_scoped(filetype))
  local frame = {
    bufnr = bufnr,
    changedtick = changedtick,
    start_row = start_row,
    end_row = end_row,
    leftcol = leftcol,
    shiftwidth = shiftwidth,
    space = space,
    breakindent = breakindent,
    filetype = filetype,
    levels = result.levels,
    whitespace_lengths = result.whitespace_lengths,
    virt_texts = {},
  } ---@type era.dressing.indentline.render.IFrame
  frames[winnr] = frame
  return frame
end

---@param frame                         era.dressing.indentline.render.IFrame
---@param row                           integer
---@param config                        era.dressing.indentline.IConfig
---@return string|nil virt_text
---@return string|nil hlgroup
function M.make_virt_text(frame, row, config)
  local level = frame.levels[row] or 0 ---@type integer
  if level < 1 or level * frame.shiftwidth <= frame.leftcol then
    return nil, nil
  end

  local symbol = config.char .. string.rep(frame.space, frame.shiftwidth - 1) ---@type string
  local symbol_plain = config.char .. string.rep(" ", frame.shiftwidth - 1) ---@type string
  local virt_text = frame.virt_texts[level] or string.rep(symbol, level) ---@type string
  frame.virt_texts[level] = virt_text

  local whitespace_length = frame.whitespace_lengths[row] or 0 ---@type integer
  if frame.space ~= " " and whitespace_length < level * frame.shiftwidth then
    if whitespace_length == 0 then
      virt_text = string.rep(symbol_plain, level)
    elseif whitespace_length % frame.shiftwidth == 0 then
      local whitespace_level = whitespace_length / frame.shiftwidth ---@type integer
      virt_text = string.rep(symbol, whitespace_level) .. string.rep(symbol_plain, level - whitespace_level)
    else
      local whitespace_level = math.floor(whitespace_length / frame.shiftwidth) ---@type integer
      local remainder = whitespace_length % frame.shiftwidth ---@type integer
      virt_text = string.rep(symbol, whitespace_level)
        .. config.char
        .. string.rep(frame.space, remainder - 1)
        .. string.rep(" ", frame.shiftwidth - remainder)
        .. string.rep(symbol_plain, level - whitespace_level - 1)
    end
  end

  if frame.leftcol > 0 then
    local byte_index = vim.str_byteindex(virt_text, "utf-32", frame.leftcol) ---@type integer
    virt_text = virt_text:sub(byte_index + 1)
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

  vim.api.nvim_win_call(winnr, function()
    for row = begin_row, last_row do
      if vim.fn.foldclosed(row + 1) ~= row + 1 then
        local virt_text, hlgroup = M.make_virt_text(frame, row, config)
        if virt_text ~= nil and hlgroup ~= nil then
          vim.api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
            ephemeral = true,
            virt_text = { { virt_text, hlgroup } },
            virt_text_pos = "overlay",
            virt_text_repeat_linebreak = frame.breakindent,
            hl_mode = "combine",
            priority = config.priority,
          })
        end
      end
    end
  end)
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
      return M.build_frame(winnr, bufnr, start_row, end_row) ~= nil
    end,
    on_range = function(_, winnr, bufnr, begin_row, _, end_row, end_col)
      draw_range(winnr, bufnr, begin_row, end_row, end_col, config)
    end,
  })
end

return M
