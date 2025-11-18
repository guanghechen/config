---@class eve.constant.hlgroup.vsc.lsp
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local palette = context.scheme.palette ---@type std.t.theme.IPalette
  local c = palette.vsc ---@type std.t.theme.IVscPalette|nil
  if not c then
    return {}
  end

  local u = palette.unified ---@type std.t.theme.UnifiedPalette

  local decorator = c.tokenControlFlowSpecialKeywords or c.tokenMarkupHeading or (c.tokenKeyword or u.fg2)
  local keyword = c.tokenKeyword or u.fg1
  local operator = c.semanticNewOperator or c.tokenKeywordOperator or (c.text or u.fg2)
  local type_color = c.tokenTypesDeclarationAndReferences or (c.accentAqua or u.brightAqua)
  local builtin_type = c.tokenStorageType or type_color
  local function_color = c.tokenFunctionDeclarations or (c.accentBlue or u.brightBlue)
  local variable = c.tokenVariableAndParameterName or (c.text or u.fg2)
  local builtin = c.tokenThisSelf or keyword
  local property_color = c.tokenObjectKeysTsGrammarSpecific or c.tokenEntityOtherAttributeName or variable
  local constant = c.tokenConstantsAndEnums or c.tokenConstantNumeric or (c.accentGreen or u.brightGreen)
  local number_color = c.semanticNumberLiteral or c.tokenConstantNumeric or (c.accentGreen or u.brightGreen)
  local string_color = c.semanticStringLiteral or c.tokenString or (c.accentOrange or u.brightOrange)
  local regexp_color = c.tokenStringRegexp or c.tokenRegularExpressionGroups or string_color
  local invalid = c.tokenInvalid or c.tokenMarkupDeleted or (c.accentRed or u.red)

  return {
    ["@lsp.mod.declaration"] = {},
    ["@lsp.mod.definition"] = {},
    ["@lsp.mod.deprecated"] = { fg = invalid, strikethrough = true },
    ["@lsp.mod.documentation"] = { fg = c.tokenComment or c.textMuted or u.fg3, italic = true },
    ["@lsp.mod.modification"] = { underline = true },
    ["@lsp.mod.readonly"] = { italic = true },
    ["@lsp.mod.static"] = { underline = true },

    ["@lsp.type.boolean"] = { fg = c.tokenConstantLanguage or keyword },
    ["@lsp.type.builtin"] = { fg = builtin_type },
    ["@lsp.type.builtinType"] = { fg = builtin_type },
    ["@lsp.type.class"] = { link = "@type" },
    ["@lsp.type.comment"] = { link = "@comment" },
    ["@lsp.type.decorator"] = { fg = decorator, italic = true },
    ["@lsp.type.enum"] = { link = "@type" },
    ["@lsp.type.enumMember"] = { fg = constant },
    ["@lsp.type.escapeSequence"] = { fg = c.tokenConstantCharacterEscape or c.tokenStringInterpolation or string_color },
    ["@lsp.type.event"] = { fg = decorator },
    ["@lsp.type.formatSpecifier"] = { fg = c.tokenConstantCharacterEscape or c.tokenStringInterpolation or string_color },
    ["@lsp.type.function"] = { fg = function_color },
    ["@lsp.type.generic"] = { link = "@variable" },
    ["@lsp.type.interface"] = { link = "@type" },
    ["@lsp.type.keyword"] = { fg = keyword, italic = true },
    ["@lsp.type.lifetime"] = { fg = keyword, italic = true },
    ["@lsp.type.macro"] = { fg = decorator },
    ["@lsp.type.method"] = { fg = function_color },
    ["@lsp.type.modifier"] = { fg = keyword },
    ["@lsp.type.namespace"] = { link = "@namespace" },
    ["@lsp.type.number"] = { fg = number_color },
    ["@lsp.type.operator"] = { fg = operator },
    ["@lsp.type.parameter"] = { fg = variable, italic = true },
    ["@lsp.type.primitive"] = { fg = builtin_type },
    ["@lsp.type.property"] = { fg = property_color },
    ["@lsp.type.regexp"] = { fg = regexp_color },
    ["@lsp.type.selfKeyword"] = { fg = builtin, italic = true },
    ["@lsp.type.selfTypeKeyword"] = { fg = type_color, italic = true },
    ["@lsp.type.string"] = { fg = string_color },
    ["@lsp.type.struct"] = { link = "@type" },
    ["@lsp.type.type"] = { fg = type_color },
    ["@lsp.type.typeAlias"] = { fg = type_color },
    ["@lsp.type.typeParameter"] = { fg = type_color },
    ["@lsp.type.unresolvedReference"] = { undercurl = true, sp = invalid },
    ["@lsp.type.variable"] = { fg = variable },

    ["@lsp.typemod.class.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.class.defaultLibrary"] = { fg = type_color, italic = true },
    ["@lsp.typemod.enum.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.enum.defaultLibrary"] = { fg = type_color, italic = true },
    ["@lsp.typemod.enumMember.declaration"] = { fg = constant },
    ["@lsp.typemod.enumMember.defaultLibrary"] = { fg = constant, italic = true },
    ["@lsp.typemod.function.builtin"] = { fg = function_color, italic = true },
    ["@lsp.typemod.function.declaration"] = { fg = function_color },
    ["@lsp.typemod.function.defaultLibrary"] = { fg = function_color, italic = true },
    ["@lsp.typemod.interface.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.keyword.async"] = { fg = decorator },
    ["@lsp.typemod.keyword.documentation"] = { fg = keyword, italic = true },
    ["@lsp.typemod.keyword.injected"] = { fg = keyword },
    ["@lsp.typemod.macro.defaultLibrary"] = { fg = decorator, italic = true },
    ["@lsp.typemod.method.builtin"] = { fg = function_color, italic = true },
    ["@lsp.typemod.method.declaration"] = { fg = function_color },
    ["@lsp.typemod.method.defaultLibrary"] = { fg = function_color, italic = true },
    ["@lsp.typemod.operator.injected"] = { fg = operator },
    ["@lsp.typemod.parameter.declaration"] = { fg = variable, italic = true },
    ["@lsp.typemod.parameter.documentation"] = { fg = variable, italic = true },
    ["@lsp.typemod.property.readonly"] = { fg = property_color, italic = true },
    ["@lsp.typemod.string.injected"] = { fg = string_color },
    ["@lsp.typemod.struct.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.struct.defaultLibrary"] = { fg = type_color, italic = true },
    ["@lsp.typemod.type.defaultLibrary"] = { fg = type_color, italic = true },
    ["@lsp.typemod.typeAlias.defaultLibrary"] = { fg = type_color, italic = true },
    ["@lsp.typemod.variable.callable"] = { fg = function_color },
    ["@lsp.typemod.variable.defaultLibrary"] = { fg = builtin, italic = true },
    ["@lsp.typemod.variable.injected"] = { fg = variable },
    ["@lsp.typemod.variable.readonly"] = { fg = variable, italic = true },
    ["@lsp.typemod.variable.static"] = { underline = true },
  }
end

return M

