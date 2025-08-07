---@class eve.constant.hlgroup.gruvbox.lsp
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette

  return {
    ["@lsp.type.class"] = { fg = c.brightYellow, bold = true },
    ["@lsp.type.class.lua"] = { fg = c.brightBlue, bold = true },
    ["@lsp.type.comment"] = { link = "Comment" },
    ["@lsp.type.decorator"] = { fg = c.brightOrange, italic = true },
    ["@lsp.type.enum"] = { fg = c.brightYellow },
    ["@lsp.type.enumMember"] = { fg = c.brightPurple },
    ["@lsp.type.event"] = { fg = c.brightRed },
    ["@lsp.type.function"] = { fg = c.brightAqua, bold = true },
    ["@lsp.type.interface"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.keyword"] = { fg = c.brightBlue, bold = true },
    ["@lsp.type.macro"] = { fg = c.brightAqua },
    ["@lsp.type.method"] = { fg = c.brightBlue, bold = true },
    ["@lsp.type.modifier"] = { fg = c.brightOrange },
    ["@lsp.type.namespace"] = { fg = c.fg1 },
    ["@lsp.type.number"] = { fg = c.brightPurple },
    ["@lsp.type.operator"] = { fg = c.brightAqua },
    ["@lsp.type.parameter"] = { fg = c.brightBlue, italic = true },
    ["@lsp.type.property"] = { fg = c.brightBlue },
    ["@lsp.type.regexp"] = { fg = c.brightRed },
    ["@lsp.type.string"] = { fg = c.brightGreen },
    ["@lsp.type.struct"] = { fg = c.brightYellow },
    ["@lsp.type.type"] = { fg = c.brightYellow },
    ["@lsp.type.typeParameter"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.variable"] = { fg = c.fg2 },

    ["@lsp.mod.declaration"] = { bold = true },
    ["@lsp.mod.definition"] = { bold = true },
    ["@lsp.mod.deprecated"] = { strikethrough = true, fg = c.grey },
    ["@lsp.mod.documentation"] = { italic = true },
    ["@lsp.mod.modification"] = { underline = true },
    ["@lsp.mod.readonly"] = { italic = true },
    ["@lsp.mod.static"] = { italic = true },

    ["@lsp.typemod.class.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.enum.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.enumMember.declaration"] = { fg = c.brightPurple, bold = true },
    ["@lsp.typemod.function.declaration"] = { fg = c.brightAqua, bold = true },
    ["@lsp.typemod.interface.declaration"] = { fg = c.brightYellow, bold = true, italic = true },
    ["@lsp.typemod.method.declaration"] = { fg = c.brightBlue, bold = true },
    ["@lsp.typemod.struct.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.type.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.variable.declaration"] = { fg = c.fg2, bold = true },
    ["@lsp.typemod.variable.readonly"] = { fg = c.brightPurple, italic = true },
    ["@lsp.typemod.variable.static"] = { fg = c.fg2, italic = true },
    ["@lsp.typemod.property.readonly"] = { fg = c.brightPurple, italic = true },
    ["@lsp.typemod.parameter.documentation"] = { fg = c.brightBlue, italic = true },
  }
end

return M
