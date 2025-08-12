---@class eve.constant.hlgroup.catppuccin.lsp
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.catppuccin ---@type std.t.theme.CatppuccinPalette

  return {
    ["@lsp.mod.declaration"] = {},
    ["@lsp.mod.definition"] = {},
    ["@lsp.mod.deprecated"] = { strikethrough = true, fg = c.overlay1 },
    ["@lsp.mod.documentation"] = { italic = true },
    ["@lsp.mod.modification"] = { underline = true },
    ["@lsp.mod.readonly"] = { italic = true },
    ["@lsp.mod.static"] = { italic = true },

    ["@lsp.type.builtin"] = { fg = c.peach },
    ["@lsp.type.class"] = { fg = c.yellow },
    ["@lsp.type.class.lua"] = { fg = c.blue },
    ["@lsp.type.comment"] = { fg = c.overlay2, italic = true },
    ["@lsp.type.decorator"] = { fg = c.yellow, italic = true },
    ["@lsp.type.enum"] = { fg = c.yellow },
    ["@lsp.type.enumMember"] = { fg = c.mauve },
    ["@lsp.type.event"] = { fg = c.red },
    ["@lsp.type.function"] = { fg = c.blue },
    ["@lsp.type.interface"] = { fg = c.yellow, italic = true },
    ["@lsp.type.keyword"] = { fg = c.mauve, bold = true },
    ["@lsp.type.keyword.lua"] = { fg = c.mauve, bold = true },
    ["@lsp.type.macro"] = { fg = c.blue },
    ["@lsp.type.method"] = { fg = c.blue },
    ["@lsp.type.modifier"] = { fg = c.yellow },
    ["@lsp.type.namespace"] = { fg = c.text },
    ["@lsp.type.namespace.typescriptreact"] = { fg = c.yellow },
    ["@lsp.type.number"] = { fg = c.peach },
    ["@lsp.type.operator"] = { fg = c.sky },
    ["@lsp.type.parameter"] = { fg = c.maroon, italic = true },
    ["@lsp.type.parameter.lua"] = { fg = c.maroon, italic = true },
    ["@lsp.type.primitive"] = { fg = c.yellow },
    ["@lsp.type.property"] = { fg = c.text },
    ["@lsp.type.regexp"] = { fg = c.pink },
    ["@lsp.type.string"] = { fg = c.green },
    ["@lsp.type.struct"] = { fg = c.yellow },
    ["@lsp.type.type"] = { fg = c.yellow },
    ["@lsp.type.typeParameter"] = { fg = c.yellow, italic = true },
    ["@lsp.type.variable"] = { fg = c.text },

    ["@lsp.typemod.class.declaration"] = { fg = c.yellow },
    ["@lsp.typemod.class.declaration.lua"] = { fg = c.subtext1, italic = true },
    ["@lsp.typemod.enum.declaration"] = { fg = c.yellow },
    ["@lsp.typemod.enumMember.declaration"] = { fg = c.mauve },
    ["@lsp.typemod.function.builtin"] = { fg = c.peach },
    ["@lsp.typemod.function.declaration"] = { fg = c.blue },
    ["@lsp.typemod.interface.declaration"] = { fg = c.yellow },
    ["@lsp.typemod.keyword.documentation.lua"] = { fg = c.blue, bold = true },
    ["@lsp.typemod.method.builtin"] = { fg = c.peach },
    ["@lsp.typemod.method.declaration"] = { fg = c.blue },
    ["@lsp.typemod.parameter.documentation"] = { fg = c.maroon, italic = true },
    ["@lsp.typemod.property.readonly"] = { fg = c.mauve, italic = true },
    ["@lsp.typemod.struct.declaration"] = { fg = c.yellow },
    ["@lsp.typemod.type.declaration"] = { fg = c.yellow },
    ["@lsp.typemod.variable.declaration"] = { fg = c.text },
    ["@lsp.typemod.variable.readonly"] = { fg = c.mauve, italic = true },
    ["@lsp.typemod.variable.readonly.typescriptreact"] = { fg = c.mauve, italic = true },
    ["@lsp.typemod.variable.static"] = { fg = c.mauve, italic = true },
  }
end

return M