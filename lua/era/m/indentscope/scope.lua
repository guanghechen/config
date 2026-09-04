---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.indentscope.scope" ---@type string

---@class era.m.indentscope.scope
local M = {}

---@class era.m.indentscope.scope.ICacheEntry
---@field public scope                  era.m.indentscope.IScope
---@field public changedtick            integer
---@field public tabstop                integer
---@field public vartabstop             string
---@field public border                 era.m.indentscope.Border
---@field public indent_at_cursor       boolean
---@field public try_as_border          boolean

local cache = nil ---@type era.m.indentscope.scope.ICacheEntry|nil

local blank_indent = {
  none = math.min,
  top = function(_, bottom)
    return bottom
  end,
  bottom = function(top)
    return top
  end,
  both = math.max,
}

---@param lnum                          integer
---@param line_count                    integer
---@param border                        era.m.indentscope.Border
---@return integer, integer|nil, integer|nil
local function compute_indent(lnum, line_count, border)
  if lnum < 1 or lnum > line_count then
    return -1, nil, nil
  end

  local previous = vim.fn.prevnonblank(lnum) ---@type integer
  if previous == lnum then
    return vim.fn.indent(lnum), nil, nil
  end

  local following = vim.fn.nextnonblank(lnum) ---@type integer
  local previous_indent = previous == 0 and -1 or vim.fn.indent(previous) ---@type integer
  local following_indent = following == 0 and -1 or vim.fn.indent(following) ---@type integer
  local indent = blank_indent[border](previous_indent, following_indent) ---@type integer
  local first_blank = previous == 0 and 1 or previous + 1 ---@type integer
  local last_blank = following == 0 and line_count or following - 1 ---@type integer
  return indent, first_blank, last_blank
end

---@param line_count                    integer
---@param border                        era.m.indentscope.Border
---@return fun(lnum: integer): integer
local function make_indent_reader(line_count, border)
  local indent_cache = {} ---@type table<integer, integer>

  return function(lnum)
    if lnum < 1 or lnum > line_count then
      return -1
    end

    local cached = indent_cache[lnum] ---@type integer|nil
    if cached ~= nil then
      return cached
    end

    local indent, first_blank, last_blank = compute_indent(lnum, line_count, border)
    if first_blank == nil or last_blank == nil then
      indent_cache[lnum] = indent
    else
      for blank_lnum = first_blank, last_blank do
        indent_cache[blank_lnum] = indent
      end
    end
    return indent
  end
end

---@param line_count                    integer
---@param border                        era.m.indentscope.Border
---@return fun(lnum: integer): integer
local function make_reference_indent_reader(line_count, border)
  return function(lnum)
    return compute_indent(lnum, line_count, border)
  end
end

---@param lnum                          integer
---@param line_count                    integer
---@param options                       era.m.indentscope.IOptions
---@param get_indent                    fun(lnum: integer): integer
---@return integer
local function correct_reference_line(lnum, line_count, options, get_indent)
  if not options.try_as_border or options.border == "none" then
    return lnum
  end

  local previous_indent = get_indent(lnum - 1) ---@type integer
  local current_indent = get_indent(lnum) ---@type integer
  local following_indent = get_indent(lnum + 1) ---@type integer

  if options.border == "top" then
    return current_indent < following_indent and math.min(lnum + 1, line_count) or lnum
  end
  if options.border == "bottom" then
    return current_indent < previous_indent and math.max(lnum - 1, 1) or lnum
  end
  if previous_indent <= current_indent and following_indent <= current_indent then
    return lnum
  end
  if previous_indent <= following_indent then
    return math.min(lnum + 1, line_count)
  end
  return math.max(lnum - 1, 1)
end

---@param lnum                          integer
---@param reference_indent              integer
---@param direction                     -1|1
---@param line_count                    integer
---@param get_indent                    fun(lnum: integer): integer
---@return integer, integer
local function cast_ray(lnum, reference_indent, direction, line_count, get_indent)
  local boundary = direction < 0 and 1 or line_count ---@type integer
  local current = lnum ---@type integer
  local minimum_indent = math.huge ---@type integer

  while current ~= boundary do
    local candidate = current + direction ---@type integer
    local candidate_indent = get_indent(candidate) ---@type integer
    if candidate_indent < reference_indent then
      return current, minimum_indent
    end
    minimum_indent = math.min(minimum_indent, candidate_indent)
    current = candidate
  end

  return current, minimum_indent
end

---@param body                          era.m.indentscope.IBody
---@param border                        era.m.indentscope.Border
---@param get_indent                    fun(lnum: integer): integer
---@return era.m.indentscope.IBorder
local function make_border(body, border, get_indent)
  local top = (border == "top" or border == "both") and body.top - 1 or nil ---@type integer|nil
  local bottom = (border == "bottom" or border == "both") and body.bottom + 1 or nil ---@type integer|nil
  local indent = nil ---@type integer|nil

  if top ~= nil then
    indent = get_indent(top)
  end
  if bottom ~= nil then
    indent = math.max(indent or -1, get_indent(bottom))
  end

  return { top = top, bottom = bottom, indent = indent }
end

---@param entry                         era.m.indentscope.scope.ICacheEntry
---@param bufnr                         integer
---@param winnr                         integer
---@param changedtick                   integer
---@param tabstop                       integer
---@param vartabstop                    string
---@param options                       era.m.indentscope.IOptions
---@return boolean
local function cache_context_matches(entry, bufnr, winnr, changedtick, tabstop, vartabstop, options)
  return entry.scope.bufnr == bufnr
    and entry.scope.winnr == winnr
    and entry.changedtick == changedtick
    and entry.tabstop == tabstop
    and entry.vartabstop == vartabstop
    and entry.border == options.border
    and entry.indent_at_cursor == options.indent_at_cursor
    and entry.try_as_border == options.try_as_border
end

---@param bufnr                         integer
---@param winnr                         integer
---@param changedtick                   integer
---@param tabstop                       integer
---@param vartabstop                    string
---@param options                       era.m.indentscope.IOptions
---@param line                          integer
---@param col                           integer
---@param reference_indent              integer
---@return era.m.indentscope.IScope|nil
local function reuse_scope(bufnr, winnr, changedtick, tabstop, vartabstop, options, line, col, reference_indent)
  local entry = cache
  local scope = entry and entry.scope or nil ---@type era.m.indentscope.IScope|nil
  if
    entry == nil
    or scope == nil
    or not cache_context_matches(entry, bufnr, winnr, changedtick, tabstop, vartabstop, options)
    or scope.reference.indent ~= reference_indent
    or line < scope.body.top
    or line > scope.body.bottom
  then
    return nil
  end

  return {
    bufnr = bufnr,
    winnr = winnr,
    body = {
      top = scope.body.top,
      bottom = scope.body.bottom,
      indent = scope.body.indent,
    },
    border = {
      top = scope.border.top,
      bottom = scope.border.bottom,
      indent = scope.border.indent,
    },
    reference = {
      line = line,
      col = col,
      indent = reference_indent,
    },
  }
end

---@param scope                         era.m.indentscope.IScope
---@param changedtick                   integer
---@param tabstop                       integer
---@param vartabstop                    string
---@param options                       era.m.indentscope.IOptions
---@return nil
local function cache_scope(scope, changedtick, tabstop, vartabstop, options)
  cache = {
    scope = vim.deepcopy(scope),
    changedtick = changedtick,
    tabstop = tabstop,
    vartabstop = vartabstop,
    border = options.border,
    indent_at_cursor = options.indent_at_cursor,
    try_as_border = options.try_as_border,
  }
end

---@param line                          ?integer
---@param col                           ?integer
---@param options                       era.m.indentscope.IOptions
---@return era.m.indentscope.IScope
function M.get(line, col, options)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local line_count = vim.api.nvim_buf_line_count(bufnr) ---@type integer
  local cursor = vim.fn.getcurpos() ---@type integer[]
  local get_reference_indent = make_reference_indent_reader(line_count, options.border) ---@type fun(lnum: integer): integer

  line = math.min(math.max(line or cursor[2], 1), line_count)
  line = correct_reference_line(line, line_count, options, get_reference_indent)
  col = col or (options.indent_at_cursor and math.max(cursor[5], 1) or math.huge)

  local line_indent = get_reference_indent(line) ---@type integer
  local reference_indent = math.min(col, line_indent) ---@type integer
  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr) ---@type integer
  local tabstop = vim.api.nvim_get_option_value("tabstop", { buf = bufnr }) ---@type integer
  local vartabstop = vim.api.nvim_get_option_value("vartabstop", { buf = bufnr }) ---@type string
  local cached = reuse_scope(bufnr, winnr, changedtick, tabstop, vartabstop, options, line, col, reference_indent)
  if cached ~= nil then
    return cached
  end

  local get_indent = make_indent_reader(line_count, options.border) ---@type fun(lnum: integer): integer
  local body ---@type era.m.indentscope.IBody

  if reference_indent <= 0 then
    body = {
      top = 1,
      bottom = line_count,
      indent = line_indent,
    }
  else
    local top, top_indent = cast_ray(line, reference_indent, -1, line_count, get_indent)
    local bottom, bottom_indent = cast_ray(line, reference_indent, 1, line_count, get_indent)
    body = {
      top = top,
      bottom = bottom,
      indent = math.min(line_indent, top_indent, bottom_indent),
    }
  end

  local scope = {
    bufnr = bufnr,
    winnr = winnr,
    body = body,
    border = make_border(body, options.border, get_indent),
    reference = {
      line = line,
      col = col,
      indent = reference_indent,
    },
  } ---@type era.m.indentscope.IScope
  cache_scope(scope, changedtick, tabstop, vartabstop, options)
  return scope
end

---@param scope                         era.m.indentscope.IScope
---@return integer
function M.get_draw_col(scope)
  return scope.border.indent or (scope.body.indent - 1)
end

---@param left                          era.m.indentscope.IScope
---@param right                         era.m.indentscope.IScope
---@return boolean
function M.equals(left, right)
  return left.bufnr == right.bufnr
    and left.winnr == right.winnr
    and M.get_draw_col(left) == M.get_draw_col(right)
    and left.body.top == right.body.top
    and left.body.bottom == right.body.bottom
end

---@param left                          era.m.indentscope.IScope
---@param right                         era.m.indentscope.IScope
---@return boolean
function M.intersects(left, right)
  if left.bufnr ~= right.bufnr or left.winnr ~= right.winnr or M.get_draw_col(left) ~= M.get_draw_col(right) then
    return false
  end
  return left.body.top <= right.body.bottom and right.body.top <= left.body.bottom
end

return M
