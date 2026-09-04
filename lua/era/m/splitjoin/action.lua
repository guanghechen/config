---@see https://github.com/nvim-mini/mini.splitjoin

--- MIT License
---
--- Copyright (c) 2021 Evgeni Chasnovski
---
--- Permission is hereby granted, free of charge, to any person obtaining a copy
--- of this software and associated documentation files (the "Software"), to deal
--- in the Software without restriction, including without limitation the rights
--- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
--- copies of the Software, and to permit persons to whom the Software is
--- furnished to do so, subject to the following conditions:
---
--- The above copyright notice and this permission notice shall be included in all
--- copies or substantial portions of the Software.
---
--- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
--- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
--- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
--- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
--- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
--- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
--- SOFTWARE.

---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.splitjoin.action" ---@type string

---@class era.m.splitjoin.INeighborhood
---@field public text                   string
---@field public lines                  string[]
---@field public line_offsets           integer[]

---@class era.m.splitjoin.ISpan
---@field public from                   integer
---@field public to                     integer

---@class era.m.splitjoin.action
local M = {}

local namespace = vim.api.nvim_create_namespace("era.m.splitjoin") ---@type integer

local BRACKET_PAIRS = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
}

local CLOSING_BRACKETS = {
  [")"] = true,
  ["]"] = true,
  ["}"] = true,
}

---@param text                          string
---@param offset                        integer
---@param char                          string
---@return boolean
local function is_quote_start(text, offset, char)
  if char == '"' then
    return true
  end
  if char ~= "'" then
    return false
  end

  local previous = text:sub(offset - 1, offset - 1) ---@type string
  local next = text:sub(offset + 1, offset + 1) ---@type string
  return not (previous:match("[%w_]") and next:match("[%w_]"))
end

---@param left                          string
---@param right                         string
---@return boolean
local function is_matching_pair(left, right)
  return BRACKET_PAIRS[left] == right
end

---@param text                          string
---@param reference_offset              integer
---@return era.m.splitjoin.ISpan|nil
local function find_region(text, reference_offset)
  if reference_offset < 1 or reference_offset > #text then
    return nil
  end

  local stack = {} ---@type { char: string, offset: integer }[]
  local quote = nil ---@type string|nil
  local offset = 1 ---@type integer
  while offset <= #text do
    local char = text:sub(offset, offset) ---@type string
    if quote ~= nil then
      if char == "\\" then
        offset = offset + 1
      elseif char == quote or char == "\n" then
        quote = nil
      end
    elseif #stack > 0 and is_quote_start(text, offset, char) then
      quote = char
    elseif BRACKET_PAIRS[char] ~= nil then
      stack[#stack + 1] = { char = char, offset = offset }
    elseif CLOSING_BRACKETS[char] then
      local opening = stack[#stack]
      if opening ~= nil and BRACKET_PAIRS[opening.char] == char then
        stack[#stack] = nil
        if opening.offset <= reference_offset and reference_offset <= offset then
          return { from = opening.offset, to = offset }
        end
      elseif opening ~= nil then
        stack = {}
      end
    end
    offset = offset + 1
  end

  return nil
end

---@param text                          string
---@param region                        era.m.splitjoin.ISpan
---@return integer[]
local function find_separators(text, region)
  local left = text:sub(region.from, region.from) ---@type string
  local right = text:sub(region.to, region.to) ---@type string
  if not is_matching_pair(left, right) then
    return {}
  end

  local result = {} ---@type integer[]
  local stack = {} ---@type string[]
  local quote = nil ---@type string|nil
  local offset = region.from + 1 ---@type integer
  local last_content_offset = region.to - 1 ---@type integer
  while last_content_offset > region.from and text:sub(last_content_offset, last_content_offset):match("%s") do
    last_content_offset = last_content_offset - 1
  end

  while offset < region.to do
    local char = text:sub(offset, offset) ---@type string
    if quote ~= nil then
      if char == "\\" then
        offset = offset + 1
      elseif char == quote or char == "\n" then
        quote = nil
      end
    elseif is_quote_start(text, offset, char) then
      quote = char
    elseif BRACKET_PAIRS[char] ~= nil then
      stack[#stack + 1] = BRACKET_PAIRS[char]
    elseif CLOSING_BRACKETS[char] then
      if stack[#stack] == char then
        stack[#stack] = nil
      end
    elseif char == "," and #stack == 0 and offset ~= last_content_offset then
      result[#result + 1] = offset
    end
    offset = offset + 1
  end

  return result
end

---@param bufnr                         integer
---@return boolean
function M.is_available(bufnr)
  return vim.api.nvim_buf_is_valid(bufnr)
    and vim.api.nvim_buf_is_loaded(bufnr)
    and not vim.api.nvim_get_option_value("readonly", { buf = bufnr })
    and vim.api.nvim_get_option_value("modifiable", { buf = bufnr })
end

---@param bufnr                         integer
---@return era.m.splitjoin.INeighborhood
local function get_neighborhood(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false) ---@type string[]
  local line_offsets = {} ---@type integer[]
  local offset = 0 ---@type integer
  for index, line in ipairs(lines) do
    line_offsets[index] = offset
    offset = offset + #line + 1
  end
  return {
    text = table.concat(lines, "\n"),
    lines = lines,
    line_offsets = line_offsets,
  }
end

---@param neighborhood                  era.m.splitjoin.INeighborhood
---@param position                      era.m.splitjoin.IPosition
---@return integer
local function position_to_offset(neighborhood, position)
  return neighborhood.line_offsets[position.row + 1] + position.col + 1
end

---@param neighborhood                  era.m.splitjoin.INeighborhood
---@param offset                        integer
---@return era.m.splitjoin.IPosition
local function offset_to_position(neighborhood, offset)
  local left = 1 ---@type integer
  local right = #neighborhood.line_offsets ---@type integer
  while left < right do
    local middle = math.floor((left + right + 1) / 2) ---@type integer
    if neighborhood.line_offsets[middle] < offset then
      left = middle
    else
      right = middle - 1
    end
  end

  local line = neighborhood.lines[left] or "" ---@type string
  local col = math.min(offset - neighborhood.line_offsets[left] - 1, #line) ---@type integer
  return { row = left - 1, col = col }
end

---@param bufnr                         integer
---@param position                      era.m.splitjoin.IPosition
---@return string
local function get_char(bufnr, position)
  local line = vim.api.nvim_buf_get_lines(bufnr, position.row, position.row + 1, true)[1] or "" ---@type string
  return line:sub(position.col + 1, position.col + 1)
end

---@param bufnr                         integer
---@param region                        era.m.splitjoin.IRegion
---@return boolean
local function is_valid_region(bufnr, region)
  if region.from.row > region.to.row or (region.from.row == region.to.row and region.from.col >= region.to.col) then
    return false
  end
  return is_matching_pair(get_char(bufnr, region.from), get_char(bufnr, region.to))
end

---@param bufnr                         integer
---@param specified                     era.m.splitjoin.IRegion|nil
---@param reference                     era.m.splitjoin.IPosition|nil
---@param neighborhood                  era.m.splitjoin.INeighborhood|nil
---@return era.m.splitjoin.IRegion|nil, era.m.splitjoin.INeighborhood|nil
local function resolve_region(bufnr, specified, reference, neighborhood)
  if specified ~= nil then
    if not is_valid_region(bufnr, specified) then
      return nil, neighborhood
    end
    return specified, neighborhood
  end

  neighborhood = neighborhood or get_neighborhood(bufnr)
  if neighborhood.text == "" then
    return nil, neighborhood
  end

  if reference == nil then
    local cursor = vim.api.nvim_win_get_cursor(0) ---@type [integer, integer]
    reference = { row = cursor[1] - 1, col = cursor[2] }
  end
  local reference_offset = position_to_offset(neighborhood, reference) ---@type integer
  local span = find_region(neighborhood.text, reference_offset) ---@type era.m.splitjoin.ISpan|nil
  if span == nil then
    return nil, neighborhood
  end

  ---@type era.m.splitjoin.IRegion
  local region = {
    from = offset_to_position(neighborhood, span.from),
    to = offset_to_position(neighborhood, span.to),
  }
  return region, neighborhood
end

---@param list                          string[]
---@param seen                          table<string, boolean>
---@param value                         string
---@return nil
local function add_unique(list, seen, value)
  if value ~= "" and not seen[value] then
    seen[value] = true
    list[#list + 1] = value
  end
end

---@param bufnr                         integer
---@return string[]
local function get_comment_leaders(bufnr)
  local result = {} ---@type string[]
  local seen = {} ---@type table<string, boolean>
  local commentstring = vim.api.nvim_get_option_value("commentstring", { buf = bufnr }) ---@type string
  local main = commentstring:match("^(.-)%%s") ---@type string|nil
  add_unique(result, seen, vim.trim(main or ""))

  local comments = vim.api.nvim_get_option_value("comments", { buf = bufnr }) ---@type string
  for part in vim.gsplit(comments, ",", { plain = true }) do
    local flags, leader = part:match("^(.*):(.*)$")
    if flags ~= nil and leader ~= nil then
      leader = vim.trim(leader)
      if flags:find("b", 1, true) then
        add_unique(result, seen, leader .. " ")
        add_unique(result, seen, leader .. "\t")
      elseif not flags:find("f", 1, true) then
        add_unique(result, seen, leader)
      end
    end
  end
  return result
end

---@param line                          string
---@param leaders                       string[]
---@return string
local function get_comment_indent(line, leaders)
  local result = "" ---@type string
  for _, leader in ipairs(leaders) do
    local current = line:match("^%s*" .. vim.pesc(leader) .. "%s*") ---@type string|nil
    if current ~= nil and #current > #result then
      result = current
    end
  end
  return result
end

---@param line                          string
---@param leaders                       string[]
---@param respect_comments              boolean
---@return string
local function get_indent_part(line, leaders, respect_comments)
  if respect_comments then
    local comment_indent = get_comment_indent(line, leaders) ---@type string
    if comment_indent ~= "" then
      return comment_indent
    end
  end
  return line:match("^%s*") or ""
end

---@param lines                         string[]
---@param leaders                       string[]
---@return boolean
local function is_comment_block(lines, leaders)
  for _, line in ipairs(lines) do
    if get_comment_indent(line, leaders) == "" then
      return false
    end
  end
  return #lines > 0
end

---@param bufnr                         integer
---@param from_row                      integer
---@param to_row                        integer
---@param leaders                       string[]
---@return nil
local function increase_indent(bufnr, from_row, to_row, leaders)
  if from_row > to_row then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, from_row, to_row + 1, true) ---@type string[]
  local respect_comments = is_comment_block(lines, leaders) ---@type boolean
  local expandtab = vim.api.nvim_get_option_value("expandtab", { buf = bufnr }) ---@type boolean
  local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = bufnr }) ---@type integer
  if shiftwidth == 0 then
    shiftwidth = vim.api.nvim_get_option_value("tabstop", { buf = bufnr })
  end
  local pad = expandtab and string.rep(" ", shiftwidth) or "\t" ---@type string

  for index, line in ipairs(lines) do
    local indent = get_indent_part(line, leaders, respect_comments) ---@type string
    if #line > #indent then
      local row = from_row + index - 1 ---@type integer
      vim.api.nvim_buf_set_text(bufnr, row, #indent, row, #indent, { pad })
    end
  end
end

---@param bufnr                         integer
---@param position                      era.m.splitjoin.IPosition
---@return integer
local function put_extmark(bufnr, position)
  return vim.api.nvim_buf_set_extmark(bufnr, namespace, position.row, position.col, {})
end

---@param bufnr                         integer
---@param extmark                       integer
---@return era.m.splitjoin.IPosition
local function get_extmark(bufnr, extmark)
  local position = vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, extmark, {}) ---@type integer[]
  return { row = position[1], col = position[2] }
end

---@param bufnr                         integer
---@param positions                     era.m.splitjoin.IPosition[]
---@param mutate                        fun(extmarks: integer[]): nil
---@return nil
local function mutate_tracked(bufnr, positions, mutate)
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local cursor = vim.api.nvim_win_get_cursor(winnr) ---@type [integer, integer]
  local cursor_extmark = put_extmark(bufnr, { row = cursor[1] - 1, col = cursor[2] }) ---@type integer
  local extmarks = {} ---@type integer[]
  for _, position in ipairs(positions) do
    extmarks[#extmarks + 1] = put_extmark(bufnr, position)
  end

  local ok, err = pcall(mutate, extmarks)
  local cursor_position = get_extmark(bufnr, cursor_extmark) ---@type era.m.splitjoin.IPosition
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  vim.api.nvim_win_set_cursor(winnr, { cursor_position.row + 1, cursor_position.col })
  if not ok then
    error(err, 0)
  end
end

---@param bufnr                         integer
---@param extmark                       integer
---@param leaders                       string[]
---@return nil
local function split_at_extmark(bufnr, extmark, leaders)
  local position = get_extmark(bufnr, extmark) ---@type era.m.splitjoin.IPosition
  vim.api.nvim_buf_set_text(bufnr, position.row, position.col + 1, position.row, position.col + 1, { "", "" })

  local split_line = vim.api.nvim_buf_get_lines(bufnr, position.row, position.row + 1, true)[1] ---@type string
  local trailing = split_line:find("%s*$") or (#split_line + 1) ---@type integer
  vim.api.nvim_buf_set_text(bufnr, position.row, trailing - 1, position.row, #split_line, {})

  local lines = vim.api.nvim_buf_get_lines(bufnr, position.row, position.row + 2, true) ---@type string[]
  local current_indent = get_indent_part(lines[1], leaders, true) ---@type string
  local next_indent = get_indent_part(lines[2], leaders, true) ---@type string
  vim.api.nvim_buf_set_text(bufnr, position.row + 1, 0, position.row + 1, #next_indent, { current_indent })
end

---@param bufnr                         integer
---@param region                        era.m.splitjoin.IRegion
---@param neighborhood                  era.m.splitjoin.INeighborhood|nil
---@return nil
local function split_region(bufnr, region, neighborhood)
  neighborhood = neighborhood or get_neighborhood(bufnr)
  ---@type era.m.splitjoin.ISpan
  local span = {
    from = position_to_offset(neighborhood, region.from),
    to = position_to_offset(neighborhood, region.to),
  }
  local positions = {} ---@type era.m.splitjoin.IPosition[]
  if span.to - span.from > 1 then
    positions[#positions + 1] = region.from
  end
  for _, separator in ipairs(find_separators(neighborhood.text, span)) do
    positions[#positions + 1] = offset_to_position(neighborhood, separator)
  end
  positions[#positions + 1] = { row = region.to.row, col = region.to.col - 1 }

  local leaders = get_comment_leaders(bufnr) ---@type string[]
  mutate_tracked(bufnr, positions, function(extmarks)
    for _, extmark in ipairs(extmarks) do
      split_at_extmark(bufnr, extmark, leaders)
    end
    local first = get_extmark(bufnr, extmarks[1]) ---@type era.m.splitjoin.IPosition
    local last = get_extmark(bufnr, extmarks[#extmarks]) ---@type era.m.splitjoin.IPosition
    increase_indent(bufnr, first.row + 1, last.row, leaders)
  end)
end

---@param bufnr                         integer
---@param extmark                       integer
---@param pad                           string
---@param leaders                       string[]
---@return nil
local function join_at_extmark(bufnr, extmark, pad, leaders)
  local position = get_extmark(bufnr, extmark) ---@type era.m.splitjoin.IPosition
  if position.row + 1 >= vim.api.nvim_buf_line_count(bufnr) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, position.row, position.row + 2, true) ---@type string[]
  local trailing = lines[1]:match("%s*$") or "" ---@type string
  local above_col = #lines[1] - #trailing ---@type integer
  local below_col = #get_indent_part(lines[2], leaders, true) ---@type integer
  vim.api.nvim_buf_set_text(bufnr, position.row, above_col, position.row + 1, below_col, { pad })
end

---@param bufnr                         integer
---@param region                        era.m.splitjoin.IRegion
---@return boolean
local function join_region(bufnr, region)
  if region.from.row == region.to.row then
    return false
  end

  local positions = {} ---@type era.m.splitjoin.IPosition[]
  local lines = vim.api.nvim_buf_get_lines(bufnr, region.from.row, region.to.row, true) ---@type string[]
  for index, line in ipairs(lines) do
    positions[#positions + 1] = { row = region.from.row + index - 1, col = #line }
  end

  local leaders = get_comment_leaders(bufnr) ---@type string[]
  mutate_tracked(bufnr, positions, function(extmarks)
    for index, extmark in ipairs(extmarks) do
      local pad = (index == 1 or index == #extmarks) and "" or " " ---@type string
      join_at_extmark(bufnr, extmark, pad, leaders)
    end
  end)
  return true
end

---@return era.m.splitjoin.IRegion
function M.get_visual_region()
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  local from = vim.api.nvim_buf_get_mark(bufnr, "<") ---@type [integer, integer]
  local to = vim.api.nvim_buf_get_mark(bufnr, ">") ---@type [integer, integer]
  local from_position = { row = from[1] - 1, col = from[2] } ---@type era.m.splitjoin.IPosition
  local to_position = { row = to[1] - 1, col = to[2] } ---@type era.m.splitjoin.IPosition
  if vim.fn.visualmode() == "V" then
    from_position.col = 0
    local line = vim.api.nvim_buf_get_lines(bufnr, to_position.row, to_position.row + 1, true)[1] or "" ---@type string
    to_position.col = math.max(#line - 1, 0)
  end
  return { from = from_position, to = to_position }
end

---@param specified                    era.m.splitjoin.IRegion|string|nil
---@return nil
function M.split(specified)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not M.is_available(bufnr) then
    return
  end

  local region, neighborhood = resolve_region(bufnr, type(specified) == "table" and specified or nil, nil, nil)
  if region == nil then
    return
  end
  if join_region(bufnr, region) then
    region, neighborhood = resolve_region(bufnr, nil, region.from, nil)
    if region == nil then
      return
    end
  end
  split_region(bufnr, region, neighborhood)
end

---@param specified                    era.m.splitjoin.IRegion|string|nil
---@return nil
function M.join(specified)
  local bufnr = vim.api.nvim_get_current_buf() ---@type integer
  if not M.is_available(bufnr) then
    return
  end
  local region = resolve_region(bufnr, type(specified) == "table" and specified or nil, nil, nil)
  if region ~= nil then
    join_region(bufnr, region)
  end
end

return M
