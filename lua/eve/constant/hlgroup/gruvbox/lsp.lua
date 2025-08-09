---@class eve.constant.hlgroup.gruvbox.lsp
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette

  return {
    ["@lsp.mod.declaration"] = { bold = true },
    ["@lsp.mod.definition"] = { bold = true },
    ["@lsp.mod.deprecated"] = { strikethrough = true, fg = c.grey },
    ["@lsp.mod.documentation"] = { italic = true },
    ["@lsp.mod.modification"] = { underline = true },
    ["@lsp.mod.readonly"] = { italic = true },
    ["@lsp.mod.static"] = { italic = true },

    ["@lsp.type.builtin"] = { fg = c.brightPurple, bold = true },
    ["@lsp.type.class"] = { fg = c.brightYellow, bold = true },
    ["@lsp.type.class.lua"] = { fg = c.brightBlue, bold = true },
    ["@lsp.type.comment"] = { link = "Comment" },
    ["@lsp.type.decorator"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.enum"] = { fg = c.brightYellow },
    ["@lsp.type.enumMember"] = { fg = c.brightPurple },
    ["@lsp.type.event"] = { fg = c.brightRed },
    ["@lsp.type.function"] = { fg = c.brightAqua, bold = true },
    ["@lsp.type.interface"] = { fg = c.brightYellow, bold = true, italic = true },
    ["@lsp.type.keyword"] = { fg = c.brightBlue, bold = true },
    ["@lsp.type.keyword.lua"] = { fg = c.brightBlue, bold = true, italic = false },
    ["@lsp.type.macro"] = { fg = c.brightAqua },
    ["@lsp.type.method"] = { fg = c.brightBlue, bold = true },
    ["@lsp.type.modifier"] = { fg = c.brightYellow },
    ["@lsp.type.namespace"] = { fg = c.fg1 },
    ["@lsp.type.namespace.typescriptreact"] = { fg = c.brightYellow },
    ["@lsp.type.number"] = { fg = c.brightPurple },
    ["@lsp.type.operator"] = { fg = c.brightGreen },
    ["@lsp.type.parameter"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.parameter.lua"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.primitive"] = { fg = c.brightYellow },
    ["@lsp.type.property"] = { fg = c.brightBlue },
    ["@lsp.type.regexp"] = { fg = c.brightRed },
    ["@lsp.type.string"] = { fg = c.brightGreen },
    ["@lsp.type.struct"] = { fg = c.brightYellow },
    ["@lsp.type.type"] = { fg = c.brightYellow },
    ["@lsp.type.typeParameter"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.variable"] = { fg = c.fg1 },

    ["@lsp.typemod.class.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.class.declaration.lua"] = { fg = c.fg4, italic = true },
    ["@lsp.typemod.enum.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.enumMember.declaration"] = { fg = c.brightPurple, bold = true },
    ["@lsp.typemod.function.builtin"] = { fg = c.brightPurple, bold = true },
    ["@lsp.typemod.function.declaration"] = { fg = c.brightAqua, bold = true },
    ["@lsp.typemod.interface.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.keyword.documentation.lua"] = { fg = c.brightBlue, bold = true },
    ["@lsp.typemod.method.builtin"] = { fg = c.brightPurple, bold = true },
    ["@lsp.typemod.method.declaration"] = { fg = c.brightBlue, bold = true },
    ["@lsp.typemod.parameter.documentation"] = { fg = c.brightBlue, italic = true },
    ["@lsp.typemod.property.readonly"] = { fg = c.brightPurple, italic = true },
    ["@lsp.typemod.struct.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.type.declaration"] = { fg = c.brightYellow, bold = true },
    ["@lsp.typemod.variable.declaration"] = { fg = c.fg1, bold = true },
    ["@lsp.typemod.variable.readonly"] = { fg = c.brightPurple, italic = true },
    ["@lsp.typemod.variable.readonly.typescriptreact"] = { fg = c.fg1, italic = true, bold = true },
    ["@lsp.typemod.variable.static"] = { fg = c.fg1, italic = true },
  }
end

return M
