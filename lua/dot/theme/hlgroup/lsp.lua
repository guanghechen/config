---@class dot.theme.hlgroup.lsp
local M = {}

---@param context                       dot.t.theme.IContext
---@return table<string, ark.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local md = string.format("dot.theme.hlgroup.%s.lsp", context.scheme.theme) ---@type string
  local ok, mod = pcall(require, md)
  if ok and mod then
    return mod.gen_hlgroup_map(context)
  end

  return M.default_gen_hlgroup_map(context)
end

---@param context                       dot.t.theme.IContext
---@return table<string, ark.t.theme.IHlgroup>
function M.default_gen_hlgroup_map(context)
  local c = context.scheme.palette.unified ---@type ark.t.theme.UnifiedPalette

  return {
    ["@lsp.mod.declaration"] = {},
    ["@lsp.mod.definition"] = {},
    ["@lsp.mod.deprecated"] = { fg = c.bg4, strikethrough = true },
    ["@lsp.mod.documentation"] = { italic = true },
    ["@lsp.mod.modification"] = { underline = true },
    ["@lsp.mod.readonly"] = { italic = true },
    ["@lsp.mod.static"] = { italic = true },
    ["@lsp.type.boolean"] = { link = "Boolean" },
    ["@lsp.type.builtin"] = { link = "Type" },
    ["@lsp.type.builtinType"] = { link = "Type" },
    ["@lsp.type.class"] = { link = "Type" },
    ["@lsp.type.class.lua"] = { link = "Type" },
    ["@lsp.type.comment"] = { link = "Comment" },
    ["@lsp.type.decorator"] = { link = "Macro" },
    ["@lsp.type.deriveHelper"] = { link = "Function" },
    ["@lsp.type.enum"] = { link = "Type" },
    ["@lsp.type.enumMember"] = { link = "Constant" },
    ["@lsp.type.escapeSequence"] = { link = "SpecialChar" },
    ["@lsp.type.event"] = { link = "Keyword" },
    ["@lsp.type.formatSpecifier"] = { link = "Special" },
    ["@lsp.type.function"] = { link = "Function" },
    ["@lsp.type.generic"] = { link = "Identifier" },
    ["@lsp.type.interface"] = { link = "Special" },
    ["@lsp.type.keyword"] = { link = "Keyword" },
    ["@lsp.type.keyword.lua"] = { link = "Keyword" },
    ["@lsp.type.label"] = { link = "Label" },
    ["@lsp.type.lifetime"] = { link = "Keyword" },
    ["@lsp.type.macro"] = { link = "Macro" },
    ["@lsp.type.method"] = { link = "Function" },
    ["@lsp.type.modifier"] = { link = "Keyword" },
    ["@lsp.type.namespace"] = { fg = c.fg1 },
    ["@lsp.type.namespace.python"] = { fg = c.fg1 },
    ["@lsp.type.namespace.typescriptreact"] = { fg = c.fg1 },
    ["@lsp.type.number"] = { link = "Number" },
    ["@lsp.type.operator"] = { link = "Operator" },
    ["@lsp.type.parameter"] = { link = "Identifier" },
    ["@lsp.type.parameter.lua"] = { link = "Identifier" },
    ["@lsp.type.primitive"] = { link = "Type" },
    ["@lsp.type.property"] = { link = "Identifier" },
    ["@lsp.type.regexp"] = { link = "Special" },
    ["@lsp.type.selfKeyword"] = { link = "Identifier" },
    ["@lsp.type.selfTypeKeyword"] = { link = "Type" },
    ["@lsp.type.string"] = { link = "String" },
    ["@lsp.type.struct"] = { link = "Type" },
    ["@lsp.type.type"] = { link = "Type" },
    ["@lsp.type.typeAlias"] = { link = "Typedef" },
    ["@lsp.type.typeParameter"] = { link = "Typedef" },
    ["@lsp.type.unresolvedReference"] = { undercurl = true, sp = c.red },
    ["@lsp.type.variable"] = { link = "Variable" },
    ["@lsp.typemod.class.declaration"] = { link = "Type" },
    ["@lsp.typemod.class.declaration.lua"] = { fg = c.fg2, italic = true },
    ["@lsp.typemod.class.defaultLibrary"] = { link = "Type" },
    ["@lsp.typemod.enum.declaration"] = { link = "Type" },
    ["@lsp.typemod.enum.defaultLibrary"] = { link = "Type" },
    ["@lsp.typemod.enumMember.declaration"] = { link = "Constant" },
    ["@lsp.typemod.enumMember.defaultLibrary"] = { link = "Constant" },
    ["@lsp.typemod.function.builtin"] = { link = "Function" },
    ["@lsp.typemod.function.declaration"] = { link = "Function" },
    ["@lsp.typemod.function.defaultLibrary"] = { link = "Function" },
    ["@lsp.typemod.interface.declaration"] = { link = "Type" },
    ["@lsp.typemod.keyword.async"] = { link = "Keyword" },
    ["@lsp.typemod.keyword.documentation.lua"] = { fg = c.fg3, italic = true },
    ["@lsp.typemod.keyword.injected"] = { link = "Keyword" },
    ["@lsp.typemod.macro.defaultLibrary"] = { link = "Macro" },
    ["@lsp.typemod.method.builtin"] = { link = "Function" },
    ["@lsp.typemod.method.declaration"] = { link = "Function" },
    ["@lsp.typemod.method.defaultLibrary"] = { link = "Function" },
    ["@lsp.typemod.operator.injected"] = { link = "Operator" },
    ["@lsp.typemod.parameter.documentation"] = { italic = true },
    ["@lsp.typemod.property.readonly"] = { italic = true },
    ["@lsp.typemod.string.injected"] = { link = "String" },
    ["@lsp.typemod.struct.declaration"] = { link = "Type" },
    ["@lsp.typemod.struct.defaultLibrary"] = { link = "Type" },
    ["@lsp.typemod.type.declaration"] = { link = "Type" },
    ["@lsp.typemod.type.defaultLibrary"] = { link = "Type" },
    ["@lsp.typemod.typeAlias.defaultLibrary"] = { link = "Typedef" },
    ["@lsp.typemod.variable.callable"] = { link = "Function" },
    ["@lsp.typemod.variable.declaration"] = { link = "Identifier" },
    ["@lsp.typemod.variable.defaultLibrary"] = { link = "Identifier" },
    ["@lsp.typemod.variable.injected"] = { link = "Identifier" },
    ["@lsp.typemod.variable.readonly"] = { italic = true },
    ["@lsp.typemod.variable.readonly.typescriptreact"] = { italic = true },
    ["@lsp.typemod.variable.static"] = { italic = true },
  }
end

return M
