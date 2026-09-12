---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.treesitter.rosepine" ---@type string

---@class dot.theme.hlgroup.treesitter.rosepine
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.rosepine ---@type stl.t.theme.IRosepinePalette

  ---@type table<string, stl.t.theme.IHlgroup>
  return {
    -- Comments
    ["@comment"] = { link = "Comment" },
    ["@comment.documentation"] = { link = "Comment" },
    ["@comment.error"] = { fg = c.love, bold = true },
    ["@comment.hint"] = { fg = c.iris, bold = true },
    ["@comment.info"] = { fg = c.foam, bold = true },
    ["@comment.note"] = { fg = c.rose, bold = true },
    ["@comment.todo"] = { link = "Todo" },
    ["@comment.warning"] = { fg = c.gold, bold = true },

    -- Identifiers
    ["@attribute"] = { fg = c.iris },
    ["@attribute.builtin"] = { link = "@attribute" },
    ["@constant"] = { link = "Constant" },
    ["@constant.builtin"] = { fg = c.rose },
    ["@constant.macro"] = { link = "Macro" },
    ["@constructor"] = { fg = c.foam },
    ["@module"] = { fg = c.text },
    ["@module.builtin"] = { fg = c.iris },
    ["@property"] = { link = "@variable.member" },
    ["@variable"] = { link = "Variable" },
    ["@variable.builtin"] = { fg = c.iris, italic = true },
    ["@variable.member"] = { fg = c.foam },
    ["@variable.parameter"] = { link = "Parameter" },
    ["@variable.parameter.builtin"] = { fg = c.iris },

    -- Literals
    ["@boolean"] = { link = "Boolean" },
    ["@character"] = { link = "Character" },
    ["@character.special"] = { link = "SpecialChar" },
    ["@number"] = { link = "Number" },
    ["@number.float"] = { link = "Float" },
    ["@string"] = { link = "String" },
    ["@string.documentation"] = { fg = c.gold, italic = true },
    ["@string.escape"] = { fg = c.pine },
    ["@string.regexp"] = { fg = c.iris },
    ["@string.special"] = { link = "Special" },
    ["@string.special.path"] = { fg = c.rose },
    ["@string.special.symbol"] = { fg = c.foam },
    ["@string.special.url"] = { fg = c.iris, underline = true },

    -- Functions
    ["@function"] = { link = "Function" },
    ["@function.builtin"] = { fg = c.rose },
    ["@function.call"] = { link = "Function" },
    ["@function.macro"] = { link = "Macro" },
    ["@function.method"] = { link = "Method" },
    ["@function.method.call"] = { link = "Method" },
    ["@operator"] = { link = "Operator" },

    -- Keywords
    ["@keyword"] = { link = "Keyword" },
    ["@keyword.conditional"] = { link = "Conditional" },
    ["@keyword.conditional.ternary"] = { link = "Operator" },
    ["@keyword.coroutine"] = { link = "Keyword" },
    ["@keyword.debug"] = { link = "Debug" },
    ["@keyword.directive"] = { link = "PreProc" },
    ["@keyword.directive.define"] = { link = "Define" },
    ["@keyword.exception"] = { link = "Exception" },
    ["@keyword.function"] = { link = "Keyword" },
    ["@keyword.import"] = { link = "Include" },
    ["@keyword.modifier"] = { link = "StorageClass" },
    ["@keyword.operator"] = { link = "Operator" },
    ["@keyword.repeat"] = { link = "Repeat" },
    ["@keyword.return"] = { link = "Keyword" },
    ["@keyword.storage"] = { link = "StorageClass" },
    ["@keyword.type"] = { link = "Type" },
    ["@label"] = { link = "Label" },

    -- Types and punctuation
    ["@type"] = { link = "Type" },
    ["@type.builtin"] = { fg = c.foam, italic = true },
    ["@type.definition"] = { link = "Typedef" },
    ["@punctuation.bracket"] = { link = "Delimiter" },
    ["@punctuation.delimiter"] = { link = "Delimiter" },
    ["@punctuation.special"] = { fg = c.iris },

    -- Markup
    ["@markup"] = { fg = c.text },
    ["@markup.environment"] = { fg = c.iris },
    ["@markup.environment.name"] = { fg = c.foam },
    ["@markup.heading"] = { fg = c.rose, bold = true },
    ["@markup.heading.1"] = { fg = c.rose, bold = true },
    ["@markup.heading.2"] = { fg = c.foam, bold = true },
    ["@markup.heading.3"] = { fg = c.iris, bold = true },
    ["@markup.heading.4"] = { fg = c.gold, bold = true },
    ["@markup.heading.5"] = { fg = c.pine, bold = true },
    ["@markup.heading.6"] = { fg = c.foam, bold = true },
    ["@markup.italic"] = { italic = true },
    ["@markup.link"] = { fg = c.iris },
    ["@markup.link.label"] = { fg = c.foam },
    ["@markup.link.url"] = { fg = c.iris, underline = true },
    ["@markup.list"] = { fg = c.muted },
    ["@markup.list.checked"] = { fg = c.pine },
    ["@markup.list.unchecked"] = { fg = c.muted },
    ["@markup.math"] = { fg = c.foam },
    ["@markup.quote"] = { fg = c.subtle, italic = true },
    ["@markup.raw"] = { fg = c.gold },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.strong"] = { bold = true },
    ["@markup.underline"] = { underline = true },

    -- Tags and diffs
    ["@tag"] = { fg = c.foam },
    ["@tag.attribute"] = { fg = c.iris },
    ["@tag.builtin"] = { link = "@tag" },
    ["@tag.delimiter"] = { fg = c.subtle },
    ["@diff.delta"] = { link = "DiffChanged" },
    ["@diff.minus"] = { link = "DiffRemoved" },
    ["@diff.plus"] = { link = "DiffAdded" },

    -- Language specific
    ["@constructor.lua"] = { link = "@punctuation.bracket" },
    ["@variable.parameter.luadoc"] = { fg = c.text, italic = true },
    ["@property.css"] = { fg = c.foam },
    ["@property.scss"] = { fg = c.foam },
    ["@label.yaml"] = { fg = c.foam },
  }
end

return M
