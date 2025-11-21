---@class eve.constant.hlgroup.vsc.lsp
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.vsc ---@type std.t.theme.IVscPalette

  return {
    ["@lsp.mod.declaration"] = {},
    ["@lsp.mod.definition"] = {},
    ["@lsp.mod.deprecated"] = {
      fg = c.tokenInvalid or c.tokenMarkupDeleted or c.accentRed,
      strikethrough = true,
    },
    ["@lsp.mod.documentation"] = { fg = c.tokenComment or c.textMuted, italic = true },
    ["@lsp.mod.modification"] = { underline = true },
    ["@lsp.mod.readonly"] = { italic = true },
    ["@lsp.mod.static"] = { underline = true },

    ["@lsp.type.boolean"] = { fg = c.tokenConstantLanguage or c.tokenKeyword },
    ["@lsp.type.builtin"] = {
      fg = c.tokenStorageType or c.tokenTypesDeclarationAndReferences or c.accentAqua,
    },
    ["@lsp.type.builtinType"] = {
      fg = c.tokenStorageType or c.tokenTypesDeclarationAndReferences or c.accentAqua,
    },
    ["@lsp.type.class"] = { link = "@type" },
    ["@lsp.type.comment"] = { link = "@comment" },
    ["@lsp.type.decorator"] = {
      fg = c.tokenControlFlowSpecialKeywords or c.tokenMarkupHeading or c.tokenKeyword,
      italic = true,
    },
    ["@lsp.type.enum"] = { link = "@type" },
    ["@lsp.type.enumMember"] = {
      fg = c.tokenConstantsAndEnums or c.tokenConstantNumeric or c.accentGreen,
    },
    ["@lsp.type.escapeSequence"] = {
      fg = c.tokenConstantCharacterEscape or c.tokenStringInterpolation or c.semanticStringLiteral
        or c.tokenString
        or c.accentOrange,
    },
    ["@lsp.type.event"] = {
      fg = c.tokenControlFlowSpecialKeywords or c.tokenMarkupHeading or c.tokenKeyword,
    },
    ["@lsp.type.formatSpecifier"] = {
      fg = c.tokenConstantCharacterEscape or c.tokenStringInterpolation or c.semanticStringLiteral
        or c.tokenString
        or c.accentOrange,
    },
    ["@lsp.type.function"] = { fg = c.tokenFunctionDeclarations or c.accentBlue },
    ["@lsp.type.generic"] = { link = "@variable" },
    ["@lsp.type.interface"] = { link = "@type" },
    ["@lsp.type.keyword"] = { fg = c.tokenKeyword, italic = true },
    ["@lsp.type.lifetime"] = { fg = c.tokenKeyword, italic = true },
    ["@lsp.type.macro"] = {
      fg = c.tokenControlFlowSpecialKeywords or c.tokenMarkupHeading or c.tokenKeyword,
    },
    ["@lsp.type.method"] = { fg = c.tokenFunctionDeclarations or c.accentBlue },
    ["@lsp.type.modifier"] = { fg = c.tokenKeyword },
    ["@lsp.type.namespace"] = { link = "@namespace" },
    ["@lsp.type.number"] = {
      fg = c.semanticNumberLiteral or c.tokenConstantNumeric or c.accentGreen,
    },
    ["@lsp.type.operator"] = {
      fg = c.semanticNewOperator or c.tokenKeywordOperator or c.text,
    },
    ["@lsp.type.parameter"] = {
      fg = c.tokenVariableAndParameterName or c.text,
      italic = true,
    },
    ["@lsp.type.primitive"] = {
      fg = c.tokenStorageType or c.tokenTypesDeclarationAndReferences or c.accentAqua,
    },
    ["@lsp.type.property"] = {
      fg = c.tokenObjectKeysTsGrammarSpecific or c.tokenEntityOtherAttributeName or c.tokenVariableAndParameterName
        or c.text,
    },
    ["@lsp.type.regexp"] = {
      fg = c.tokenStringRegexp or c.tokenRegularExpressionGroups or c.semanticStringLiteral or c.tokenString
        or c.accentOrange,
    },
    ["@lsp.type.selfKeyword"] = {
      fg = c.tokenThisSelf or c.tokenKeyword,
      italic = true,
    },
    ["@lsp.type.selfTypeKeyword"] = {
      fg = c.tokenTypesDeclarationAndReferences or c.accentAqua,
      italic = true,
    },
    ["@lsp.type.string"] = {
      fg = c.semanticStringLiteral or c.tokenString or c.accentOrange,
    },
    ["@lsp.type.struct"] = { link = "@type" },
    ["@lsp.type.type"] = { fg = c.tokenTypesDeclarationAndReferences or c.accentAqua },
    ["@lsp.type.typeAlias"] = { fg = c.tokenTypesDeclarationAndReferences or c.accentAqua },
    ["@lsp.type.typeParameter"] = { fg = c.tokenTypesDeclarationAndReferences or c.accentAqua },
    ["@lsp.type.unresolvedReference"] = {
      undercurl = true,
      sp = c.tokenInvalid or c.tokenMarkupDeleted or c.accentRed,
    },
    ["@lsp.type.variable"] = { fg = c.tokenVariableAndParameterName or c.text },

    ["@lsp.typemod.class.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.class.defaultLibrary"] = {
      fg = c.tokenTypesDeclarationAndReferences or c.accentAqua,
      italic = true,
    },
    ["@lsp.typemod.enum.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.enum.defaultLibrary"] = {
      fg = c.tokenTypesDeclarationAndReferences or c.accentAqua,
      italic = true,
    },
    ["@lsp.typemod.enumMember.declaration"] = {
      fg = c.tokenConstantsAndEnums or c.tokenConstantNumeric or c.accentGreen,
    },
    ["@lsp.typemod.enumMember.defaultLibrary"] = {
      fg = c.tokenConstantsAndEnums or c.tokenConstantNumeric or c.accentGreen,
      italic = true,
    },
    ["@lsp.typemod.function.builtin"] = {
      fg = c.tokenFunctionDeclarations or c.accentBlue,
      italic = true,
    },
    ["@lsp.typemod.function.declaration"] = { fg = c.tokenFunctionDeclarations or c.accentBlue },
    ["@lsp.typemod.function.defaultLibrary"] = {
      fg = c.tokenFunctionDeclarations or c.accentBlue,
      italic = true,
    },
    ["@lsp.typemod.interface.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.keyword.async"] = {
      fg = c.tokenControlFlowSpecialKeywords or c.tokenMarkupHeading or c.tokenKeyword,
    },
    ["@lsp.typemod.keyword.documentation"] = { fg = c.tokenKeyword, italic = true },
    ["@lsp.typemod.keyword.injected"] = { fg = c.tokenKeyword },
    ["@lsp.typemod.macro.defaultLibrary"] = {
      fg = c.tokenControlFlowSpecialKeywords or c.tokenMarkupHeading or c.tokenKeyword,
      italic = true,
    },
    ["@lsp.typemod.method.builtin"] = {
      fg = c.tokenFunctionDeclarations or c.accentBlue,
      italic = true,
    },
    ["@lsp.typemod.method.declaration"] = { fg = c.tokenFunctionDeclarations or c.accentBlue },
    ["@lsp.typemod.method.defaultLibrary"] = {
      fg = c.tokenFunctionDeclarations or c.accentBlue,
      italic = true,
    },
    ["@lsp.typemod.operator.injected"] = {
      fg = c.semanticNewOperator or c.tokenKeywordOperator or c.text,
    },
    ["@lsp.typemod.parameter.declaration"] = {
      fg = c.tokenVariableAndParameterName or c.text,
      italic = true,
    },
    ["@lsp.typemod.parameter.documentation"] = {
      fg = c.tokenVariableAndParameterName or c.text,
      italic = true,
    },
    ["@lsp.typemod.property.readonly"] = {
      fg = c.tokenObjectKeysTsGrammarSpecific or c.tokenEntityOtherAttributeName or c.tokenVariableAndParameterName
        or c.text,
      italic = true,
    },
    ["@lsp.typemod.string.injected"] = {
      fg = c.semanticStringLiteral or c.tokenString or c.accentOrange,
    },
    ["@lsp.typemod.struct.declaration"] = { link = "@type.definition" },
    ["@lsp.typemod.struct.defaultLibrary"] = {
      fg = c.tokenTypesDeclarationAndReferences or c.accentAqua,
      italic = true,
    },
    ["@lsp.typemod.type.defaultLibrary"] = {
      fg = c.tokenTypesDeclarationAndReferences or c.accentAqua,
      italic = true,
    },
    ["@lsp.typemod.typeAlias.defaultLibrary"] = {
      fg = c.tokenTypesDeclarationAndReferences or c.accentAqua,
      italic = true,
    },
    ["@lsp.typemod.variable.callable"] = { fg = c.tokenFunctionDeclarations or c.accentBlue },
    ["@lsp.typemod.variable.defaultLibrary"] = {
      fg = c.tokenThisSelf or c.tokenKeyword,
      italic = true,
    },
    ["@lsp.typemod.variable.injected"] = { fg = c.tokenVariableAndParameterName or c.text },
    ["@lsp.typemod.variable.readonly"] = {
      fg = c.tokenVariableAndParameterName or c.text,
      italic = true,
    },
    ["@lsp.typemod.variable.static"] = { underline = true },
  }
end

return M
