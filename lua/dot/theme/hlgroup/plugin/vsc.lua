---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.plugin.vsc" ---@type string

---@class dot.theme.hlgroup.plugin.vsc
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.vsc ---@type stl.t.theme.IVscPalette
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local cmp_panel_bg = t and c.none or cs.mix(c.overlay, c.base, 70) ---@type string
  local treesitter_context_bg = t and c.none or c.overlay ---@type string
  local badge_fg = u.bg1 ---@type string
  local panel_bg = t and c.none or cs.mix(c.base, c.overlay, 60) ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  return {
    ---! completion
    CmpDoc = { fg = c.text, bg = cmp_panel_bg },
    CmpDocBorder = { fg = c.border, bg = cmp_panel_bg },
    CmpDocSeparator = { fg = c.textMuted, bg = cmp_panel_bg },
    CmpKindClass = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    CmpKindColor = { fg = c.tokenCssPropertyValue, bg = c.none },
    CmpKindConstant = { fg = c.tokenConstantsAndEnums, bg = c.none },
    CmpKindConstructor = { fg = c.tokenFunctionDeclarations, bg = c.none },
    CmpKindEnum = { fg = c.tokenConstantsAndEnums, bg = c.none },
    CmpKindEnumMember = { fg = c.tokenConstantsAndEnums, bg = c.none },
    CmpKindEvent = { fg = c.warning, bg = c.none },
    CmpKindField = { fg = c.tokenVariableAndParameterName, bg = c.none },
    CmpKindFile = { fg = c.text, bg = c.none },
    CmpKindFolder = { fg = c.accentBlue, bg = c.none },
    CmpKindFunction = { fg = c.tokenFunctionDeclarations, bg = c.none },
    CmpKindInterface = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    CmpKindKeyword = { fg = c.tokenKeyword, bg = c.none },
    CmpKindMethod = { fg = c.tokenFunctionDeclarations, bg = c.none },
    CmpKindModule = { fg = c.tokenKeyword, bg = c.none },
    CmpKindOperator = { fg = c.semanticNewOperator, bg = c.none },
    CmpKindProperty = { fg = c.tokenObjectKeysTsGrammarSpecific, bg = c.none },
    CmpKindReference = { fg = c.tokenMarkupInlineRaw, bg = c.none },
    CmpKindSnippet = { fg = c.textMuted, bg = c.none },
    CmpKindStruct = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    CmpKindText = { fg = c.tokenString, bg = c.none },
    CmpKindTypeParameter = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    CmpKindUnit = { fg = c.tokenConstantsAndEnums, bg = c.none },
    CmpKindValue = { fg = c.tokenConstantsAndEnums, bg = c.none },
    CmpKindVariable = { fg = c.tokenVariableAndParameterName, bg = c.none },
    CmpLabelDeprecated = { fg = c.textMuted, bg = c.none, strikethrough = true },
    CmpSignatureHelp = { fg = c.text, bg = cmp_panel_bg },
    CmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    CmpSignatureHelpBorder = { fg = c.border, bg = cmp_panel_bg },

    ---! flash.nvim
    FlashBackdrop = { fg = c.textMuted },
    FlashCurrent = { fg = c.accentBlue, italic = true, bold = true },
    FlashLabel = { fg = t and c.none or c.base, bg = c.accentPurple, bold = true },
    FlashMatch = { fg = c.warning, italic = true },
    FlashPrompt = { fg = c.text, bg = cs.mix(t and c.none or c.overlay, c.border, 12) },
    FlashPromptIcon = { fg = c.accentOrange, bg = c.none },

    ---! mason.nvim
    MasonHeader = { fg = u.pink, bg = c.none },
    MasonHighlight = { fg = c.accentBlue },
    MasonHighlightBlock = { fg = badge_fg, bg = u.pink, bold = true },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = u.fg1 },
    MasonMutedBlock = { fg = u.fg1 },
    MasonNormal = { fg = c.text, bg = panel_bg, blend = t and 0 or 40 },

    ---! mini.icons
    MiniIconsAzure = { fg = c.accentBlue },
    MiniIconsBlue = { fg = c.accentBlue },
    MiniIconsCyan = { fg = c.accentAqua },
    MiniIconsGreen = { fg = c.success },
    MiniIconsGrey = { fg = c.textDim },
    MiniIconsOrange = { fg = c.accentOrange },
    MiniIconsPurple = { fg = c.accentPurple },
    MiniIconsRed = { fg = c.accentRed },
    MiniIconsYellow = { fg = c.accentYellow },

    ---! snacks.nvim
    SnacksPickerLabel = { fg = c.accentBlue, bold = true },
    SnacksPickerFile = { fg = c.accentAqua },

    ---! notify.nvim
    NotifyERRORIcon = { fg = c.accentRed },
    NotifyWARNIcon = { fg = c.accentYellow },
    NotifyINFOIcon = { fg = c.success },
    NotifyDEBUGIcon = { fg = c.accentOrange },
    NotifyTRACEIcon = { fg = c.textDim },
    NotifyERRORTitle = { link = "NotifyERRORIcon" },
    NotifyWARNTitle = { link = "NotifyWARNIcon" },
    NotifyINFOTitle = { link = "NotifyINFOIcon" },
    NotifyDEBUGTitle = { link = "NotifyDEBUGIcon" },
    NotifyTRACETitle = { link = "NotifyTRACEIcon" },

    ---! treesitter-context
    TreesitterContext = { fg = c.text, bg = treesitter_context_bg },
    TreesitterContextBottom = { underline = true, sp = c.accentBlue },
    TreesitterContextLineNumber = {
      fg = c.accentOrange,
      bg = treesitter_context_bg,
    },
    TreesitterContextLineNumberBottom = { underline = true, sp = c.accentBlue },
  }
end

return M
