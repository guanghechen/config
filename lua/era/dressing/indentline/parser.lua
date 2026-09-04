---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.indentline.parser" ---@type string

---@class era.dressing.indentline.parser.IResult
---@field public levels                 table<integer, integer>
---@field public blank_rows             table<integer, true>
---@field public tab_whitespaces        table<integer, string>
---@field public whitespace_widths      table<integer, integer>

---@class era.dressing.indentline.parser.IOptions
---@field public shiftwidth             integer
---@field public tabstop                integer
---@field public vartabstops            integer[]

---@class era.dressing.indentline.parser.IContext
---@field public previous_level         ?integer
---@field public following_level        ?integer

---@class era.dressing.indentline.parser
local M = {}

local DEDENT_SCOPED_FILETYPES = {
  automake = true,
  bzl = true,
  cabal = true,
  cabalconfig = true,
  cabalproject = true,
  chaskell = true,
  clean = true,
  earthfile = true,
  elm = true,
  fsharp = true,
  gdscript = true,
  haml = true,
  haskell = true,
  haskellpersistent = true,
  idris2 = true,
  just = true,
  kivy = true,
  lean = true,
  lhaskell = true,
  lidris2 = true,
  make = true,
  moonscript = true,
  ninja = true,
  nim = true,
  pug = true,
  purescript = true,
  pyrex = true,
  python = true,
  raml = true,
  roc = true,
  sage = true,
  salt = true,
  sass = true,
  snakemake = true,
  starlark = true,
  stylus = true,
  yaml = true,
} ---@type table<string, true>

---@param filetype                      string
---@return boolean
function M.is_dedent_scoped(filetype)
  return DEDENT_SCOPED_FILETYPES[filetype] == true
end

---@param bufnr                         integer
---@return era.dressing.indentline.parser.IOptions
function M.get_options(bufnr)
  local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", { buf = bufnr }) ---@type integer
  local tabstop = vim.api.nvim_get_option_value("tabstop", { buf = bufnr }) ---@type integer
  local vartabstop = vim.api.nvim_get_option_value("vartabstop", { buf = bufnr }) ---@type string
  local vartabstops = {} ---@type integer[]
  if vartabstop ~= "" then
    for value in vartabstop:gmatch("[^,]+") do
      local width = tonumber(value) ---@type integer|nil
      if width ~= nil and width > 0 then
        vartabstops[#vartabstops + 1] = width
      end
    end
  end
  if shiftwidth == 0 then
    shiftwidth = vartabstops[1] or tabstop
  end

  return {
    shiftwidth = math.max(shiftwidth, 1),
    tabstop = math.max(tabstop, 1),
    vartabstops = vartabstops,
  }
end

---@param col                           integer
---@param options                       era.dressing.indentline.parser.IOptions
---@return integer
function M.get_next_tabstop(col, options)
  local vartabstops = options.vartabstops ---@type integer[]
  if #vartabstops == 0 then
    return col + options.tabstop - (col % options.tabstop)
  end

  local offset = 0 ---@type integer
  for _, width in ipairs(vartabstops) do
    local next_offset = offset + width ---@type integer
    if col < next_offset then
      return next_offset
    end
    offset = next_offset
  end

  local width = vartabstops[#vartabstops] ---@type integer
  return offset + (math.floor((col - offset) / width) + 1) * width
end

---@param line                          string
---@param options                       era.dressing.indentline.parser.IOptions
---@return integer indent_level
---@return boolean is_all_whitespace
---@return integer whitespace_width
---@return string|nil tab_whitespace
function M.get_indent_level(line, options)
  local _, whitespace_end = line:find("^%s*")
  whitespace_end = whitespace_end or 0
  local first_tab = nil ---@type integer|nil
  for index = 1, whitespace_end do
    if line:byte(index) == 9 then
      first_tab = index
      break
    end
  end
  if first_tab == nil then
    return math.floor(whitespace_end / options.shiftwidth), whitespace_end == #line, whitespace_end, nil
  end

  local width = first_tab - 1 ---@type integer
  for index = first_tab, whitespace_end do
    if line:byte(index) == 9 then
      width = M.get_next_tabstop(width, options)
    else
      width = width + 1
    end
  end
  return math.floor(width / options.shiftwidth), whitespace_end == #line, width, line:sub(1, whitespace_end)
end

---@param lines                         string[]
---@param start_row                     integer
---@param options                       era.dressing.indentline.parser.IOptions
---@param dedent_scoped                 boolean
---@param context                       ?era.dressing.indentline.parser.IContext
---@return era.dressing.indentline.parser.IResult
function M.parse(lines, start_row, options, dedent_scoped, context)
  local levels = {} ---@type table<integer, integer>
  local blank_rows = {} ---@type table<integer, true>
  local tab_whitespaces = {} ---@type table<integer, string>
  local whitespace_widths = {} ---@type table<integer, integer>
  local whitespace_lines_before = 0 ---@type integer
  local previous_level = context and context.previous_level or 0 ---@type integer

  for index, line in ipairs(lines) do
    local row = start_row + index - 1 ---@type integer
    local level, is_all_whitespace, whitespace_width, tab_whitespace = M.get_indent_level(line, options)
    levels[row] = level
    tab_whitespaces[row] = tab_whitespace
    whitespace_widths[row] = whitespace_width

    if is_all_whitespace then
      blank_rows[row] = true
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

  local following_level = context and context.following_level or nil ---@type integer|nil
  if whitespace_lines_before > 0 and following_level ~= nil then
    local end_row = start_row + #lines - 1 ---@type integer
    local whitespace_level = dedent_scoped and following_level or math.max(following_level, previous_level) ---@type integer
    for whitespace_row = end_row - whitespace_lines_before + 1, end_row do
      levels[whitespace_row] = whitespace_level
    end
  end

  return {
    levels = levels,
    blank_rows = blank_rows,
    tab_whitespaces = tab_whitespaces,
    whitespace_widths = whitespace_widths,
  }
end

return M
