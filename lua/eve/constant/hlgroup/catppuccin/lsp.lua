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
    ["@lsp.type.class"] = { link = "@type" },
    ["@lsp.type.class.lua"] = { link = "@type" },
    ["@lsp.type.comment"] = { fg = c.overlay2, italic = true },
    ["@lsp.type.decorator"] = { fg = c.yellow, italic = true },
    ["@lsp.type.enum"] = { link = "@type" },
    ["@lsp.type.enumMember"] = { fg = c.teal },
    ["@lsp.type.event"] = { fg = c.red },
    ["@lsp.type.function"] = { link = "@function" },
    ["@lsp.type.interface"] = { link = "@type" },
    ["@lsp.type.keyword"] = { link = "@keyword" },
    ["@lsp.type.keyword.lua"] = { link = "@keyword" },
    ["@lsp.type.macro"] = { link = "@function.macro" },
    ["@lsp.type.method"] = { link = "@function.method" },
    ["@lsp.type.modifier"] = { link = "@keyword" },
    ["@lsp.type.namespace"] = { link = "@module" },
    ["@lsp.type.namespace.typescriptreact"] = { link = "@module" },
    ["@lsp.type.number"] = { link = "@number" },
    ["@lsp.type.operator"] = { link = "@operator" },
    ["@lsp.type.parameter"] = { link = "@variable.parameter" },
    ["@lsp.type.parameter.lua"] = { link = "@variable.parameter" },
    ["@lsp.type.primitive"] = { link = "@type.builtin" },
    ["@lsp.type.property"] = { link = "@property" },
    ["@lsp.type.regexp"] = { link = "@string.regexp" },
    ["@lsp.type.string"] = { link = "@string" },
    ["@lsp.type.struct"] = { link = "@type" },
    ["@lsp.type.type"] = { link = "@type" },
    ["@lsp.type.typeParameter"] = { link = "@type.definition" },
    ["@lsp.type.variable"] = { link = "@variable" },
    ["@lsp.typemod.class.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.class.declaration.lua"] = { fg = c.subtext1, italic = true },
    ["@lsp.typemod.enum.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.enumMember.declaration"] = { fg = c.teal },
    ["@lsp.typemod.function.builtin"] = { link = "@function.builtin" },
    ["@lsp.typemod.function.defaultLibrary"] = { link = "@function.builtin" },
    ["@lsp.typemod.function.declaration"] = { link = "@function" },
    ["@lsp.typemod.interface.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.keyword.documentation.lua"] = { fg = c.blue },
    ["@lsp.typemod.method.builtin"] = { link = "@function.builtin" },
    ["@lsp.typemod.method.declaration"] = { link = "@function" },
    ["@lsp.typemod.parameter.documentation"] = { fg = c.maroon, italic = true },
    ["@lsp.typemod.property.readonly"] = { italic = true },
    ["@lsp.typemod.struct.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.type.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.variable.declaration"] = { link = "@variable" },
    ["@lsp.typemod.variable.readonly"] = { italic = true },
    ["@lsp.typemod.variable.readonly.typescriptreact"] = { italic = true },
    ["@lsp.typemod.variable.static"] = { italic = true },
  }
end

return M
