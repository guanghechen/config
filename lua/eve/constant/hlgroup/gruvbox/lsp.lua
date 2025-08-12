---@class eve.constant.hlgroup.gruvbox.lsp
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette

  return {
    ["@lsp.mod.declaration"] = {},
    ["@lsp.mod.definition"] = {},
    ["@lsp.mod.deprecated"] = { strikethrough = true, fg = c.grey },
    ["@lsp.mod.documentation"] = { italic = true },
    ["@lsp.mod.modification"] = { underline = true },
    ["@lsp.mod.readonly"] = { italic = true },
    ["@lsp.mod.static"] = { italic = true },

    ["@lsp.type.builtin"] = { fg = c.brightPurple },
    ["@lsp.type.class"] = { fg = c.brightYellow },
    ["@lsp.type.class.lua"] = { fg = c.brightBlue },
    ["@lsp.type.comment"] = { fg = c.grey, italic = true },
    ["@lsp.type.decorator"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.enum"] = { fg = c.brightYellow },
    ["@lsp.type.enumMember"] = { fg = c.brightPurple },
    ["@lsp.type.event"] = { fg = c.brightRed },
    ["@lsp.type.function"] = { fg = c.brightAqua },
    ["@lsp.type.interface"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.keyword"] = { fg = c.brightRed, bold = true },
    ["@lsp.type.keyword.lua"] = { fg = c.brightRed, bold = true },
    ["@lsp.type.macro"] = { fg = c.brightAqua },
    ["@lsp.type.method"] = { fg = c.brightBlue },
    ["@lsp.type.modifier"] = { fg = c.brightYellow },
    ["@lsp.type.namespace"] = { fg = c.fg1 },
    ["@lsp.type.namespace.typescriptreact"] = { fg = c.brightYellow },
    ["@lsp.type.number"] = { fg = c.brightPurple },
    ["@lsp.type.operator"] = { fg = c.brightRed },
    ["@lsp.type.parameter"] = { fg = c.brightBlue, italic = true },
    ["@lsp.type.parameter.lua"] = { fg = c.brightBlue, italic = true },
    ["@lsp.type.primitive"] = { fg = c.brightYellow },
    ["@lsp.type.property"] = { fg = c.brightBlue },
    ["@lsp.type.regexp"] = { fg = c.brightRed },
    ["@lsp.type.string"] = { fg = c.brightGreen },
    ["@lsp.type.struct"] = { fg = c.brightYellow },
    ["@lsp.type.type"] = { fg = c.brightYellow },
    ["@lsp.type.typeParameter"] = { fg = c.brightYellow, italic = true },
    ["@lsp.type.variable"] = { fg = c.fg2 },

    ["@lsp.typemod.class.declaration"] = { fg = c.brightYellow },
    ["@lsp.typemod.class.declaration.lua"] = { fg = c.fg4, italic = true },
    ["@lsp.typemod.enum.declaration"] = { fg = c.brightYellow },
    ["@lsp.typemod.enumMember.declaration"] = { fg = c.brightPurple },
    ["@lsp.typemod.function.builtin"] = { fg = c.brightPurple },
    ["@lsp.typemod.function.declaration"] = { fg = c.brightAqua },
    ["@lsp.typemod.interface.declaration"] = { fg = c.brightYellow },
    ["@lsp.typemod.keyword.documentation.lua"] = { fg = c.brightBlue, bold = true },
    ["@lsp.typemod.method.builtin"] = { fg = c.brightPurple },
    ["@lsp.typemod.method.declaration"] = { fg = c.brightBlue },
    ["@lsp.typemod.parameter.documentation"] = { fg = c.brightBlue, italic = true },
    ["@lsp.typemod.property.readonly"] = { fg = c.brightPurple, italic = true },
    ["@lsp.typemod.struct.declaration"] = { fg = c.brightYellow },
    ["@lsp.typemod.type.declaration"] = { fg = c.brightYellow },
    ["@lsp.typemod.variable.declaration"] = { fg = c.fg2 },
    ["@lsp.typemod.variable.readonly"] = { fg = c.brightPurple, italic = true },
    ["@lsp.typemod.variable.readonly.typescriptreact"] = { fg = c.brightPurple, italic = true },
    ["@lsp.typemod.variable.static"] = { fg = c.brightPurple, italic = true },
  }
end

return M
