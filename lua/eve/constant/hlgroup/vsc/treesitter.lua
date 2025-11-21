---@class eve.constant.hlgroup.vsc.treesitter
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.vsc ---@type std.t.theme.IVscPalette
  local t = context.transparency ---@type boolean

  ---@type table<string, std.t.theme.IHlgroup>
  local hlgroup_map = {
    -- Comments
    ["@comment"] = { fg = c.tokenComment, italic = true },
    ["@comment.documentation"] = { fg = c.tokenComment, italic = true },
    ["@comment.error"] = { fg = c.editor_background, bg = t and c.none or c.tokenInvalid },
    ["@comment.warning"] = { fg = c.editor_background, bg = t and c.none or c.tokenMarkupDeleted },
    ["@comment.note"] = { fg = c.editor_background, bg = t and c.none or c.tokenMarkupInserted },
    ["@comment.todo"] = { fg = c.editor_background, bg = t and c.none or c.tokenMarkupHeading, bold = true },

    -- Identifiers
    ["@attribute"] = { fg = c.tokenEntityOtherAttributeName },
    ["@attribute.builtin"] = { fg = c.tokenThisSelf, italic = true },
    ["@constant"] = { fg = c.tokenConstantsAndEnums },
    ["@constant.builtin"] = { fg = c.tokenConstantLanguage, italic = true },
    ["@constant.macro"] = { fg = c.tokenControlFlowSpecialKeywords, italic = true },
    ["@field"] = { fg = c.tokenObjectKeysTsGrammarSpecific },
    ["@module"] = { fg = c.tokenTypesDeclarationAndReferences, italic = true },
    ["@namespace"] = { fg = c.tokenTypesDeclarationAndReferences, italic = true },
    ["@parameter"] = { fg = c.tokenVariableAndParameterName, italic = true },
    ["@property"] = { fg = c.tokenObjectKeysTsGrammarSpecific },
    ["@symbol"] = { fg = c.tokenConstantsAndEnums },
    ["@variable"] = { fg = c.tokenVariableAndParameterName },
    ["@variable.builtin"] = { fg = c.tokenThisSelf, italic = true },
    ["@variable.member"] = { fg = c.tokenObjectKeysTsGrammarSpecific },
    ["@variable.parameter"] = { fg = c.tokenVariableAndParameterName, italic = true },

    -- Literals
    ["@boolean"] = { fg = c.tokenConstantLanguage },
    ["@character"] = { fg = c.semanticStringLiteral },
    ["@number"] = { fg = c.semanticNumberLiteral },
    ["@number.float"] = { fg = c.semanticNumberLiteral },
    ["@string"] = { fg = c.semanticStringLiteral },
    ["@string.documentation"] = { fg = c.tokenMarkupInlineRaw },
    ["@string.escape"] = { fg = c.tokenConstantCharacterEscape },
    ["@string.regexp"] = { fg = c.tokenStringRegexp },
    ["@string.special"] = { fg = c.tokenMarkupInlineRaw },
    ["@string.special.symbol"] = { fg = c.tokenConstantsAndEnums },
    ["@string.special.url"] = { fg = c.tokenMarkupHeading, underline = true },

    -- Functions
    ["@constructor"] = { fg = c.tokenTypesDeclarationAndReferences },
    ["@function"] = { fg = c.tokenFunctionDeclarations },
    ["@function.builtin"] = { fg = c.tokenThisSelf },
    ["@function.call"] = { fg = c.tokenFunctionDeclarations },
    ["@function.macro"] = { fg = c.tokenControlFlowSpecialKeywords, italic = true },
    ["@function.method"] = { fg = c.tokenFunctionDeclarations },
    ["@method"] = { fg = c.tokenFunctionDeclarations },
    ["@operator"] = { fg = c.semanticNewOperator },

    -- Keywords
    ["@keyword"] = { fg = c.tokenKeyword, italic = true },
    ["@keyword.conditional"] = { fg = c.tokenControlFlowSpecialKeywords, italic = true },
    ["@keyword.debug"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.directive"] = { fg = c.tokenControlFlowSpecialKeywords, italic = true },
    ["@keyword.exception"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.function"] = { fg = c.tokenControlFlowSpecialKeywords, italic = true },
    ["@keyword.import"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.modifier"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.operator"] = { fg = c.semanticNewOperator },
    ["@keyword.repeat"] = { fg = c.tokenControlFlowSpecialKeywords, italic = true },
    ["@keyword.return"] = { fg = c.tokenControlFlowSpecialKeywords, italic = true },
    ["@keyword.storage"] = { fg = c.tokenControlFlowSpecialKeywords },
    ["@keyword.type"] = { fg = c.tokenTypesDeclarationAndReferences },

    -- Types
    ["@label"] = { fg = c.tokenEntityNameTag },
    ["@type"] = { fg = c.tokenTypesDeclarationAndReferences },
    ["@type.builtin"] = { fg = c.tokenStorageType },
    ["@type.definition"] = { fg = c.tokenTypesDeclarationAndReferences },
    ["@type.qualifier"] = { fg = c.tokenControlFlowSpecialKeywords },

    -- Punctuation
    ["@punctuation.bracket"] = { fg = c.tokenBracketsOfXmlHtmlTags },
    ["@punctuation.delimiter"] = { fg = c.tokenBracketsOfXmlHtmlTags },
    ["@punctuation.special"] = { fg = c.tokenBracketsOfXmlHtmlTags },

    -- Markup
    ["@markup.heading"] = { fg = c.tokenMarkupHeading, bold = true },
    ["@markup.italic"] = { fg = c.tokenMarkupBold, italic = true },
    ["@markup.link"] = { fg = c.tokenMarkupHeading, underline = true },
    ["@markup.link.label"] = { fg = c.tokenMarkupHeading },
    ["@markup.link.url"] = { fg = c.tokenMarkupHeading, underline = true },
    ["@markup.list"] = { fg = c.tokenMarkupHeading },
    ["@markup.quote"] = { fg = c.tokenComment },
    ["@markup.raw"] = { fg = c.tokenMarkupInlineRaw },
    ["@markup.strikethrough"] = { fg = c.tokenMarkupDeleted, strikethrough = true },
    ["@markup.strong"] = { fg = c.tokenMarkupBold, bold = true },
    ["@markup.underline"] = { underline = true },
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
    ["@text"] = { fg = c.tokenVariableAndParameterName },
    ["@text.danger"] = { fg = c.editor_background, bg = t and c.none or c.tokenInvalid },
    ["@text.diff.add"] = { fg = c.tokenMarkupInserted },
    ["@text.diff.delete"] = { fg = c.tokenMarkupDeleted },
    ["@text.emphasis"] = { fg = c.tokenMarkupBold, italic = true },
    ["@text.literal"] = { fg = c.tokenMarkupInlineRaw },
    ["@text.note"] = { fg = c.editor_background, bg = t and c.none or c.tokenMarkupInserted },
    ["@text.reference"] = { fg = c.tokenMarkupHeading },
    ["@text.strike"] = { fg = c.tokenMarkupDeleted, strikethrough = true },
    ["@text.strong"] = { fg = c.tokenMarkupBold, bold = true },
    ["@text.title"] = { fg = c.tokenMarkupHeading, bold = true },
    ["@text.todo"] = { fg = c.editor_background, bg = t and c.none or c.tokenMarkupChanged, bold = true, italic = true },
    ["@text.underline"] = { underline = true },
    ["@text.uri"] = { fg = c.tokenMarkupHeading, underline = true },

    -- Diff compatibility
    ["@diff.plus"] = { fg = c.tokenMarkupInserted },
    ["@diff.minus"] = { fg = c.tokenMarkupDeleted },
    ["@diff.delta"] = { fg = c.tokenMarkupChanged },
  }

  return hlgroup_map
end

return M
