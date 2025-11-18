---@class eve.constant.hlgroup.vsc.treesitter
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
  local t = context.transparency ---@type boolean

  local comment = c.tokenComment or c.status or c.textMuted or u.fg4
  local keyword = c.tokenKeyword or c.accentPurple or u.brightPurple
  local control_keyword = c.tokenControlFlowSpecialKeywords or keyword
  local operator_color = c.semanticNewOperator or c.tokenKeywordOperator or (c.text or u.fg1)
  local type_color = c.tokenTypesDeclarationAndReferences or c.accentAqua or u.brightAqua
  local builtin_type = c.tokenStorageType or type_color
  local function_color = c.tokenFunctionDeclarations or c.accentBlue or u.brightBlue
  local variable = c.tokenVariableAndParameterName or (c.text or u.fg2)
  local builtin = c.tokenThisSelf or keyword
  local constant = c.tokenConstantsAndEnums or c.tokenConstantNumeric or c.brightAqua or u.brightAqua
  local number_color = c.semanticNumberLiteral or c.tokenConstantNumeric or c.accentGreen or u.brightGreen
  local boolean_color = c.tokenConstantLanguage or keyword
  local string_color = c.semanticStringLiteral or c.tokenString or c.accentOrange or u.brightOrange
  local string_escape = c.tokenConstantCharacterEscape or c.tokenStringInterpolation or string_color
  local regex_color = c.tokenStringRegexp or c.tokenRegularExpressionGroups or string_color
  local attribute_color = c.tokenEntityOtherAttributeName or c.tokenSupportTypeVendoredPropertyName or type_color
  local property_color = c.tokenObjectKeysTsGrammarSpecific or c.tokenMetaStructureDictionaryKeyPython or variable
  local tag_color = c.tokenEntityNameTag or c.tokenCssTagsInSelectorsXmlTags or c.tokenEntityNameSelector or c.tokenBracketsOfXmlHtmlTags or keyword
  local delimiter_color = c.tokenBracketsOfXmlHtmlTags or operator_color
  local markup_heading = c.tokenMarkupHeading or function_color
  local markup_bold = c.tokenMarkupBold or markup_heading
  local markup_code = c.tokenMarkupInlineRaw or string_color
  local markup_inserted = c.tokenMarkupInserted or c.accentGreen or u.brightGreen
  local markup_deleted = c.tokenMarkupDeleted or c.accentRed or u.brightRed
  local markup_changed = c.tokenMarkupChanged or c.accentYellow or u.brightYellow
  local invalid = c.tokenInvalid or c.accentRed or u.red

  ---@type table<string, std.t.theme.IHlgroup>
  local hlgroup_map = {
    -- Comments
    ["@comment"] = { fg = comment, italic = true },
    ["@comment.documentation"] = { fg = comment, italic = true },
    ["@comment.error"] = { fg = u.bg0, bg = t and c.none or invalid },
    ["@comment.warning"] = { fg = u.bg0, bg = t and c.none or markup_deleted },
    ["@comment.note"] = { fg = u.bg0, bg = t and c.none or markup_inserted },
    ["@comment.todo"] = { fg = u.bg0, bg = t and c.none or markup_heading, bold = true },

    -- Identifiers
    ["@attribute"] = { fg = attribute_color },
    ["@attribute.builtin"] = { fg = builtin, italic = true },
    ["@constant"] = { fg = constant },
    ["@constant.builtin"] = { fg = boolean_color, italic = true },
    ["@constant.macro"] = { fg = control_keyword, italic = true },
    ["@field"] = { fg = property_color },
    ["@module"] = { fg = type_color, italic = true },
    ["@namespace"] = { fg = type_color, italic = true },
    ["@parameter"] = { fg = variable, italic = true },
    ["@property"] = { fg = property_color },
    ["@symbol"] = { fg = constant },
    ["@variable"] = { fg = variable },
    ["@variable.builtin"] = { fg = builtin, italic = true },
    ["@variable.member"] = { fg = property_color },
    ["@variable.parameter"] = { fg = variable, italic = true },

    -- Literals
    ["@boolean"] = { fg = boolean_color },
    ["@character"] = { fg = string_color },
    ["@number"] = { fg = number_color },
    ["@number.float"] = { fg = number_color },
    ["@string"] = { fg = string_color },
    ["@string.documentation"] = { fg = markup_code },
    ["@string.escape"] = { fg = string_escape },
    ["@string.regexp"] = { fg = regex_color },
    ["@string.special"] = { fg = markup_code },
    ["@string.special.symbol"] = { fg = constant },
    ["@string.special.url"] = { fg = markup_heading, underline = true },

    -- Functions
    ["@constructor"] = { fg = type_color },
    ["@function"] = { fg = function_color },
    ["@function.builtin"] = { fg = builtin },
    ["@function.call"] = { fg = function_color },
    ["@function.macro"] = { fg = control_keyword, italic = true },
    ["@function.method"] = { fg = function_color },
    ["@method"] = { fg = function_color },
    ["@operator"] = { fg = operator_color },

    -- Keywords
    ["@keyword"] = { fg = keyword, italic = true },
    ["@keyword.conditional"] = { fg = control_keyword, italic = true },
    ["@keyword.debug"] = { fg = control_keyword },
    ["@keyword.directive"] = { fg = control_keyword, italic = true },
    ["@keyword.exception"] = { fg = control_keyword },
    ["@keyword.function"] = { fg = control_keyword, italic = true },
    ["@keyword.import"] = { fg = control_keyword },
    ["@keyword.modifier"] = { fg = control_keyword },
    ["@keyword.operator"] = { fg = operator_color },
    ["@keyword.repeat"] = { fg = control_keyword, italic = true },
    ["@keyword.return"] = { fg = control_keyword, italic = true },
    ["@keyword.storage"] = { fg = control_keyword },
    ["@keyword.type"] = { fg = type_color },

    -- Types
    ["@label"] = { fg = tag_color },
    ["@type"] = { fg = type_color },
    ["@type.builtin"] = { fg = builtin_type },
    ["@type.definition"] = { fg = type_color },
    ["@type.qualifier"] = { fg = control_keyword },

    -- Punctuation
    ["@punctuation.bracket"] = { fg = delimiter_color },
    ["@punctuation.delimiter"] = { fg = delimiter_color },
    ["@punctuation.special"] = { fg = delimiter_color },

    -- Markup
    ["@markup.heading"] = { fg = markup_heading, bold = true },
    ["@markup.italic"] = { fg = markup_bold, italic = true },
    ["@markup.link"] = { fg = markup_heading, underline = true },
    ["@markup.link.label"] = { fg = markup_heading },
    ["@markup.link.url"] = { fg = markup_heading, underline = true },
    ["@markup.list"] = { fg = markup_heading },
    ["@markup.quote"] = { fg = comment },
    ["@markup.raw"] = { fg = markup_code },
    ["@markup.strikethrough"] = { fg = markup_deleted, strikethrough = true },
    ["@markup.strong"] = { fg = markup_bold, bold = true },
    ["@markup.underline"] = { underline = true },
    ["@markup.deleted"] = { fg = markup_deleted },
    ["@markup.inserted"] = { fg = markup_inserted },
    ["@markup.math"] = { fg = number_color },
    ["@markup.changed"] = { fg = markup_changed },

    -- Tags
    ["@tag"] = { fg = tag_color },
    ["@tag.attribute"] = { fg = attribute_color },
    ["@tag.builtin"] = { fg = tag_color },
    ["@tag.delimiter"] = { fg = delimiter_color },

    -- Legacy text groups
    ["@text"] = { fg = variable },
    ["@text.danger"] = { fg = u.bg0, bg = t and c.none or invalid },
    ["@text.diff.add"] = { fg = markup_inserted },
    ["@text.diff.delete"] = { fg = markup_deleted },
    ["@text.emphasis"] = { fg = markup_bold, italic = true },
    ["@text.literal"] = { fg = markup_code },
    ["@text.note"] = { fg = u.bg0, bg = t and c.none or markup_inserted },
    ["@text.reference"] = { fg = markup_heading },
    ["@text.strike"] = { fg = markup_deleted, strikethrough = true },
    ["@text.strong"] = { fg = markup_bold, bold = true },
    ["@text.title"] = { fg = markup_heading, bold = true },
    ["@text.todo"] = { fg = u.bg0, bg = t and c.none or markup_changed, bold = true, italic = true },
    ["@text.underline"] = { underline = true },
    ["@text.uri"] = { fg = markup_heading, underline = true },

    -- Diff compatibility
    ["@diff.plus"] = { fg = markup_inserted },
    ["@diff.minus"] = { fg = markup_deleted },
    ["@diff.delta"] = { fg = markup_changed },
  }

  return hlgroup_map
end

return M

