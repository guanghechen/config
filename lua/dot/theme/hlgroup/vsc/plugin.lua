---@class dot.theme.hlgroup.vsc.plugin
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.vsc ---@type stl.t.theme.IVscPalette
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local cmp_panel_bg = cs.mix(c.overlay, c.base, 70) ---@type string
  local treesitter_context_bg = t and c.none or c.overlay ---@type string
  local badge_fg = u.bg1 ---@type string
  local panel_bg = cs.mix(t and c.none or c.base, t and c.none or c.overlay, 60) ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  return {
    ---! blink.cmp
    BlinkCmpDoc = { fg = c.text, bg = cmp_panel_bg },
    BlinkCmpDocBorder = { fg = c.border, bg = cmp_panel_bg },
    BlinkCmpDocSeparator = { fg = c.textMuted, bg = cmp_panel_bg },
    BlinkCmpGhostText = { fg = c.textMuted, default = true },
    BlinkCmpItemIdx = { fg = c.textDim, bg = c.none },
    BlinkCmpKindClass = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    BlinkCmpKindCodeium = { fg = c.success, bg = c.none },
    BlinkCmpKindColor = { fg = c.tokenCssPropertyValue, bg = c.none },
    BlinkCmpKindConstant = { fg = c.tokenConstantsAndEnums, bg = c.none },
    BlinkCmpKindConstructor = { fg = c.tokenFunctionDeclarations, bg = c.none },
    BlinkCmpKindDefault = { fg = c.textDim, bg = c.none },
    BlinkCmpKindEnum = { fg = c.tokenConstantsAndEnums, bg = c.none },
    BlinkCmpKindEnumMember = { fg = c.tokenConstantsAndEnums, bg = c.none },
    BlinkCmpKindEvent = { fg = c.warning, bg = c.none },
    BlinkCmpKindField = { fg = c.tokenVariableAndParameterName, bg = c.none },
    BlinkCmpKindFile = { fg = c.text, bg = c.none },
    BlinkCmpKindFolder = { fg = c.accentBlue, bg = c.none },
    BlinkCmpKindFunction = { fg = c.tokenFunctionDeclarations, bg = c.none },
    BlinkCmpKindIdentifier = { fg = c.tokenVariableAndParameterName, bg = c.none },
    BlinkCmpKindInterface = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    BlinkCmpKindKeyword = { fg = c.tokenKeyword, bg = c.none },
    BlinkCmpKindMethod = { fg = c.tokenFunctionDeclarations, bg = c.none },
    BlinkCmpKindModule = { fg = c.tokenKeyword, bg = c.none },
    BlinkCmpKindOperator = { fg = c.semanticNewOperator, bg = c.none },
    BlinkCmpKindProperty = { fg = c.tokenObjectKeysTsGrammarSpecific, bg = c.none },
    BlinkCmpKindReference = { fg = c.tokenMarkupInlineRaw, bg = c.none },
    BlinkCmpKindSnippet = { fg = c.textMuted, bg = c.none },
    BlinkCmpKindStruct = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    BlinkCmpKindStructure = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    BlinkCmpKindSupermaven = { fg = c.success, bg = c.none },
    BlinkCmpKindTabNine = { fg = c.success, bg = c.none },
    BlinkCmpKindText = { fg = c.tokenString, bg = c.none },
    BlinkCmpKindType = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    BlinkCmpKindTypeParameter = { fg = c.tokenTypesDeclarationAndReferences, bg = c.none },
    BlinkCmpKindUnit = { fg = c.tokenConstantsAndEnums, bg = c.none },
    BlinkCmpKindValue = { fg = c.tokenConstantsAndEnums, bg = c.none },
    BlinkCmpKindVariable = { fg = c.tokenVariableAndParameterName, bg = c.none },
    BlinkCmpLabel = { fg = c.text, bg = c.none },
    BlinkCmpLabelDeprecated = { fg = c.textMuted, bg = c.none, strikethrough = true },
    BlinkCmpLabelMatch = { fg = c.accentBlue, bg = c.none, bold = true },
    BlinkCmpMenu = { fg = c.text, bg = cmp_panel_bg },
    BlinkCmpMenuBorder = { fg = c.border, bg = cmp_panel_bg },
    BlinkCmpMenuSelection = { fg = c.menu_selectionForeground, bg = c.menu_selectionBackground },
    BlinkCmpScrollBarGutter = { bg = cmp_panel_bg },
    BlinkCmpScrollBarThumb = { bg = c.border },
    BlinkCmpSignatureHelp = { fg = c.text, bg = cmp_panel_bg },
    BlinkCmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    BlinkCmpSignatureHelpBorder = { fg = c.border, bg = cmp_panel_bg },
    BlinkCmpSource = { fg = c.textDim, bg = c.none },

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

    ---! mini.indentscope
    MiniIndentscopeSymbol = { fg = c.accentPurple },
    MiniIndentscopeSymbolOff = { fg = c.accentRed },

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
