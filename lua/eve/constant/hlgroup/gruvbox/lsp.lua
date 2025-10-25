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

    ["@lsp.type.builtin"] = { link = "@type.builtin" },
    ["@lsp.type.class"] = { link = "@type" },
    ["@lsp.type.class.lua"] = { link = "@type" },
    ["@lsp.type.comment"] = { link = "@comment" },
    ["@lsp.type.decorator"] = { link = "@macro" },
    ["@lsp.type.enum"] = { link = "@type" },
    ["@lsp.type.enumMember"] = { link = "@constant" },
    ["@lsp.type.event"] = { link = "@keyword" },
    ["@lsp.type.function"] = { link = "@function" },
    ["@lsp.type.interface"] = { link = "@type" },
    ["@lsp.type.keyword"] = { link = "@keyword" },
    ["@lsp.type.keyword.lua"] = { link = "@keyword" },
    ["@lsp.type.macro"] = { link = "@macro" },
    ["@lsp.type.method"] = { link = "@method" },
    ["@lsp.type.modifier"] = { link = "@keyword" },
    ["@lsp.type.namespace"] = { link = "@namespace" },
    ["@lsp.type.namespace.typescriptreact"] = { link = "@namespace" },
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
    ["@lsp.typemod.class.declaration.lua"] = { fg = c.fg4, italic = true },
    ["@lsp.typemod.enum.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.enumMember.declaration"] = { link = "@constant" },
    ["@lsp.typemod.function.builtin"] = { link = "@function.builtin" },
    ["@lsp.typemod.function.defaultLibrary"] = { link = "@function.builtin" },
    ["@lsp.typemod.function.declaration"] = { link = "@function" },
    ["@lsp.typemod.interface.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.keyword.documentation.lua"] = { fg = c.brightBlue, italic = true },
    ["@lsp.typemod.method.builtin"] = { link = "@function.builtin" },
    ["@lsp.typemod.method.declaration"] = { link = "@function" },
    ["@lsp.typemod.parameter.documentation"] = { fg = c.brightBlue, italic = true },
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
