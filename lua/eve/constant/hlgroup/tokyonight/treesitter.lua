---@class eve.constant.hlgroup.tokyonight.treesitter
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = std.color
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.tokyonight ---@type std.t.theme.TokyonightPalette

  ---@type table<string, std.t.theme.IHlgroup>
  local hlgroup_map = {
    ["@annotation"] = { link = "PreProc" },
    ["@attribute"] = { link = "PreProc" },
    ["@boolean"] = { link = "Boolean" },
    ["@character"] = { link = "Character" },
    ["@character.printf"] = { link = "SpecialChar" },
    ["@character.special"] = { link = "SpecialChar" },
    ["@comment"] = { link = "Comment" },
    ["@comment.error"] = { fg = c.red },
    ["@comment.hint"] = { fg = c.hint },
    ["@comment.info"] = { fg = c.info },
    ["@comment.note"] = { fg = c.hint },
    ["@comment.todo"] = { fg = c.todo },
    ["@comment.warning"] = { fg = c.warning },
    ["@constant"] = { link = "Constant" },
    ["@constant.builtin"] = { link = "Special" },
    ["@constant.macro"] = { link = "Define" },
    ["@constructor"] = { fg = c.magenta },
    ["@constructor.tsx"] = { fg = c.blue1 },
    ["@diff.delta"] = { link = "DiffChange" },
    ["@diff.minus"] = { link = "DiffDelete" },
    ["@diff.plus"] = { link = "DiffAdd" },
    ["@function"] = { link = "Function" },
    ["@function.builtin"] = { link = "Special" },
    ["@function.call"] = { link = "@function" },
    ["@function.macro"] = { link = "Macro" },
    ["@function.method"] = { link = "Function" },
    ["@function.method.call"] = { link = "@function.method" },
    ["@keyword"] = { fg = c.purple },
    ["@keyword.conditional"] = { link = "Conditional" },
    ["@keyword.coroutine"] = { link = "@keyword" },
    ["@keyword.debug"] = { link = "Debug" },
    ["@keyword.directive"] = { link = "PreProc" },
    ["@keyword.directive.define"] = { link = "Define" },
    ["@keyword.exception"] = { link = "Exception" },
    ["@keyword.function"] = { fg = c.magenta },
    ["@keyword.import"] = { link = "Include" },
    ["@keyword.operator"] = { link = "@operator" },
    ["@keyword.repeat"] = { link = "Repeat" },
    ["@keyword.return"] = { link = "@keyword" },
    ["@keyword.storage"] = { link = "StorageClass" },
    ["@label"] = { fg = c.blue },
    ["@markup"] = { link = "@none" },
    ["@markup.emphasis"] = { italic = true },
    ["@markup.environment"] = { link = "Macro" },
    ["@markup.environment.name"] = { link = "Type" },
    ["@markup.heading"] = { link = "Title" },
    ["@markup.italic"] = { italic = true },
    ["@markup.link"] = { fg = c.teal },
    ["@markup.link.label"] = { link = "SpecialChar" },
    ["@markup.link.label.symbol"] = { link = "Identifier" },
    ["@markup.link.url"] = { link = "Underlined" },
    ["@markup.list"] = { fg = c.blue5 },
    ["@markup.list.checked"] = { fg = c.green1 },
    ["@markup.list.markdown"] = { fg = c.orange, bold = true },
    ["@markup.list.unchecked"] = { fg = c.blue },
    ["@markup.math"] = { link = "Special" },
    ["@markup.raw"] = { link = "String" },
    ["@markup.raw.markdown_inline"] = { bg = c.terminal_black, fg = c.blue },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.strong"] = { bold = true },
    ["@markup.underline"] = { underline = true },
    ["@module"] = { link = "Include" },
    ["@module.builtin"] = { fg = c.red },
    ["@namespace.builtin"] = { link = "@variable.builtin" },
    ["@none"] = {},
    ["@number"] = { link = "Number" },
    ["@number.float"] = { link = "Float" },
    ["@operator"] = { fg = c.blue5 },
    ["@property"] = { fg = c.green1 },
    ["@punctuation.bracket"] = { fg = c.fg_dark },
    ["@punctuation.delimiter"] = { fg = c.blue5 },
    ["@punctuation.special"] = { fg = c.blue5 },
    ["@punctuation.special.markdown"] = { fg = c.orange },
    ["@string"] = { link = "String" },
    ["@string.documentation"] = { fg = c.yellow },
    ["@string.escape"] = { fg = c.magenta },
    ["@string.regexp"] = { fg = c.blue6 },
    ["@tag"] = { link = "Label" },
    ["@tag.attribute"] = { link = "@property" },
    ["@tag.delimiter"] = { link = "Delimiter" },
    ["@tag.delimiter.tsx"] = { fg = cs.mix(c.blue, c.bg, 70) },
    ["@tag.tsx"] = { fg = c.red },
    ["@tag.javascript"] = { fg = c.red },
    ["@type"] = { link = "Type" },
    ["@type.builtin"] = { fg = cs.mix(c.blue1, c.bg, 20) },
    ["@type.definition"] = { link = "Typedef" },
    ["@type.qualifier"] = { link = "@keyword" },
    ["@variable"] = { fg = c.fg },
    ["@variable.builtin"] = { fg = c.red },
    ["@variable.member"] = { fg = c.green1 },
    ["@variable.parameter"] = { fg = c.yellow },
    ["@variable.parameter.builtin"] = { fg = cs.mix(c.yellow, c.fg, 80) },
  }

  local rainbow = {
    c.blue,
    c.yellow,
    c.green,
    c.teal,
    c.cyan,
    c.magenta,
  }

  for i, color in ipairs(rainbow) do
    hlgroup_map["@markup.heading." .. i .. ".markdown"] = {
      fg = color,
      bold = true,
      bg = cs.mix(c.bg, color, 10),
    }
  end

  return hlgroup_map
end

return M
