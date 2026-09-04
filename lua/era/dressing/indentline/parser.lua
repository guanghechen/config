---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.indentline.parser" ---@type string

---@class era.dressing.indentline.parser.IResult
---@field public levels                 table<integer, integer>
---@field public whitespace_lengths     table<integer, integer>

---@class era.dressing.indentline.parser
local M = {}

local DEDENT_SCOPED_FILETYPES = {
  fsharp = true,
  haskell = true,
  makefile = true,
  nim = true,
  python = true,
  yaml = true,
} ---@type table<string, true>

---@param filetype                      string
---@return boolean
function M.is_dedent_scoped(filetype)
  return DEDENT_SCOPED_FILETYPES[filetype] == true
end

---@param bufnr                         integer
---@return integer
function M.get_shiftwidth(bufnr)
  local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = bufnr }) ---@type integer
  if shiftwidth == 0 then
    shiftwidth = vim.api.nvim_get_option_value("tabstop", { buf = bufnr }) ---@type integer
  end
  return math.max(shiftwidth, 2)
end

---@param line                          string
---@param shiftwidth                    integer
---@return integer indent_level
---@return boolean is_all_whitespace
---@return integer whitespace_length
function M.get_indent_level(line, shiftwidth)
  local whitespace = line:match("^%s*") or "" ---@type string
  local width = #whitespace ---@type integer
  if whitespace:find("\t", 1, true) ~= nil then
    width = #whitespace:gsub("\t", string.rep(" ", shiftwidth))
  end
  return math.floor(width / shiftwidth), #whitespace == #line, #whitespace
end

---@param lines                         string[]
---@param start_row                     integer
---@param shiftwidth                    integer
---@param dedent_scoped                 boolean
---@return era.dressing.indentline.parser.IResult
function M.parse(lines, start_row, shiftwidth, dedent_scoped)
  local levels = {} ---@type table<integer, integer>
  local whitespace_lengths = {} ---@type table<integer, integer>
  local whitespace_lines_before = 0 ---@type integer
  local previous_level = 0 ---@type integer

  for index, line in ipairs(lines) do
    local row = start_row + index - 1 ---@type integer
    local level, is_all_whitespace, whitespace_length = M.get_indent_level(line, shiftwidth)
    levels[row] = level
    whitespace_lengths[row] = whitespace_length

    if is_all_whitespace then
      whitespace_lines_before = whitespace_lines_before + 1
    else
      local whitespace_level = dedent_scoped and level or math.max(level, previous_level) ---@type integer
      for whitespace_row = row - whitespace_lines_before, row - 1 do
        levels[whitespace_row] = whitespace_level
      end
      whitespace_lines_before = 0
      previous_level = level
    end
  end

  return { levels = levels, whitespace_lengths = whitespace_lengths }
end

return M
