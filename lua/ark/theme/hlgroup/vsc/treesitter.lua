---@class ark.theme.hlgroup.vsc.treesitter
local M = {}

---@param context                       ark.t.theme.IContext
---@return table<string, ark.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.vsc ---@type ark.t.theme.IVscPalette

  ---@type table<string, ark.t.theme.IHlgroup>
  local hlgroup_map = {
    -- Comments
    ["@comment"] = { fg = c.tokenComment },
    ["@comment.documentation"] = { fg = c.tokenComment },
    ["@comment.error"] = { fg = c.tokenInvalid, bold = true },
    ["@comment.warning"] = { fg = c.tokenMarkupDeleted, bold = true },
    ["@comment.note"] = { fg = c.tokenMarkupInserted, bold = true },
    ["@comment.todo"] = { fg = c.tokenMarkupHeading, bold = true },

    -- Identifiers
    ["@attribute"] = { fg = c.tokenEntityOtherAttributeName },
    ["@attribute.builtin"] = { fg = c.tokenThisSelf },
    ["@constant"] = { fg = c.tokenConstantsAndEnums },
    ["@constant.builtin"] = { fg = c.tokenConstantLanguage },
    ["@constant.macro"] = { fg = c.tokenMetaPreprocessor },
    ["@field"] = { fg = c.tokenObjectKeysTsGrammarSpecific },
    ["@module"] = { fg = c.tokenTypesDeclarationAndReferences },
    ["@namespace"] = { fg = c.tokenTypesDeclarationAndReferences },
    ["@parameter"] = { fg = c.tokenVariableAndParameterName },
    ["@property"] = { fg = c.tokenObjectKeysTsGrammarSpecific },
    ["@symbol"] = { fg = c.tokenConstantsAndEnums },
    ["@variable"] = { fg = c.tokenVariableAndParameterName },
    ["@variable.builtin"] = { fg = c.tokenThisSelf },
    ["@variable.member"] = { fg = c.tokenObjectKeysTsGrammarSpecific },
    ["@variable.parameter"] = { fg = c.tokenVariableAndParameterName },

    -- Literals
    ["@boolean"] = { fg = c.tokenConstantLanguage },
    ["@character"] = { fg = c.semanticStringLiteral },
    ["@number"] = { fg = c.semanticNumberLiteral },
    ["@number.float"] = { fg = c.semanticNumberLiteral },
    ["@string"] = { fg = c.semanticStringLiteral },
    ["@string.documentation"] = { fg = c.semanticStringLiteral },
    ["@string.escape"] = { fg = c.tokenConstantCharacterEscape },
    ["@string.regexp"] = { fg = c.tokenStringRegexp },
    ["@string.special"] = { fg = c.tokenMarkupInlineRaw },
    ["@string.special.symbol"] = { fg = c.tokenConstantsAndEnums },
    ["@string.special.url"] = { fg = c.textLink_foreground, underline = true },

    -- Functions
    ["@constructor"] = { fg = c.tokenTypesDeclarationAndReferences },
    ["@function"] = { fg = c.tokenFunctionDeclarations },
    ["@function.builtin"] = { fg = c.tokenFunctionDeclarations },
    ["@function.call"] = { fg = c.tokenFunctionDeclarations },
    ["@function.macro"] = { fg = c.tokenMetaPreprocessor },
    ["@function.method"] = { fg = c.tokenFunctionDeclarations },
    ["@method"] = { fg = c.tokenFunctionDeclarations },
    ["@operator"] = { fg = c.tokenKeywordOperator },

    -- Keywords
    ["@keyword"] = { fg = c.tokenKeyword },
    ["@keyword.conditional"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.debug"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.directive"] = { fg = c.tokenMetaPreprocessor },
    ["@keyword.exception"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.function"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.import"] = { fg = c.tokenKeyword },
    ["@keyword.modifier"] = { fg = c.tokenStorageModifier },
    ["@keyword.operator"] = { fg = c.tokenKeywordOperator },
    ["@keyword.repeat"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.return"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.storage"] = { fg = c.tokenStorage },
    ["@keyword.type"] = { fg = c.tokenStorageType },

    -- Types
    ["@label"] = { fg = c.tokenEntityNameLabel },
    ["@type"] = { fg = c.tokenTypesDeclarationAndReferences },
    ["@type.builtin"] = { fg = c.tokenStorageType },
    ["@type.definition"] = { fg = c.tokenTypesDeclarationAndReferences },
    ["@type.qualifier"] = { fg = c.tokenStorageModifier },

    -- Punctuation
    ["@punctuation.bracket"] = { fg = c.tokenKeywordOperator },
    ["@punctuation.delimiter"] = { fg = c.tokenKeywordOperator },
    ["@punctuation.special"] = { fg = c.tokenKeywordOperator },

    -- Markup
    ["@markup.heading"] = { fg = c.tokenMarkupHeading, bold = true },
    ["@markup.italic"] = { italic = true },
    ["@markup.link"] = { fg = c.textLink_foreground, underline = true },
    ["@markup.link.label"] = { fg = c.tokenMarkupHeading },
    ["@markup.link.url"] = { fg = c.textLink_foreground, underline = true },
    ["@markup.list"] = { fg = c.tokenPunctuationDefinitionListBeginMarkdown },
    ["@markup.quote"] = { fg = c.tokenComment },
    ["@markup.raw"] = { fg = c.tokenMarkupInlineRaw },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.strong"] = { fg = c.tokenMarkupBold, bold = true },
    ["@markup.underline"] = { fg = c.tokenMarkupHeading, underline = true },
    ["@markup.deleted"] = { fg = c.tokenMarkupDeleted },
    ["@markup.inserted"] = { fg = c.tokenMarkupInserted },
    ["@markup.math"] = { fg = c.semanticNumberLiteral },
    ["@markup.changed"] = { fg = c.tokenMarkupChanged },

    -- Tags
    ["@tag"] = { fg = c.tokenEntityNameTag },
    ["@tag.attribute"] = { fg = c.tokenEntityOtherAttributeName },
    ["@tag.builtin"] = { fg = c.tokenEntityNameTag },
    ["@tag.delimiter"] = { fg = c.tokenBracketsOfXmlHtmlTags },

    -- Legacy text groups
    ["@text"] = { fg = c.editor_foreground },
    ["@text.danger"] = { fg = c.tokenInvalid, bold = true },
    ["@text.diff.add"] = { fg = c.tokenMarkupInserted },
    ["@text.diff.delete"] = { fg = c.tokenMarkupDeleted },
    ["@text.emphasis"] = { italic = true },
    ["@text.literal"] = { fg = c.tokenMarkupInlineRaw },
    ["@text.note"] = { fg = c.tokenMarkupInserted },
    ["@text.reference"] = { fg = c.textLink_foreground, underline = true },
    ["@text.strike"] = { strikethrough = true },
    ["@text.strong"] = { fg = c.tokenMarkupBold, bold = true },
    ["@text.title"] = { fg = c.tokenMarkupHeading, bold = true },
    ["@text.todo"] = { fg = c.tokenMarkupHeading, bold = true },
    ["@text.underline"] = { underline = true },
    ["@text.uri"] = { fg = c.textLink_foreground, underline = true },

    -- Diff compatibility
    ["@diff.plus"] = { fg = c.tokenMarkupInserted },
    ["@diff.minus"] = { fg = c.tokenMarkupDeleted },
    ["@diff.delta"] = { fg = c.tokenMarkupChanged },
  }

  return hlgroup_map
end

return M
