---@class eve.constant.hlgroup.vsc.plugin
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = std.color
  local palette = context.scheme.palette ---@type std.t.theme.IPalette
  local c = palette.vsc ---@type std.t.theme.IVscPalette|nil
  if not c then
    return require("eve.constant.hlgroup.plugin").default_gen_hlgroup_map(context)
  end

  local u = palette.unified ---@type std.t.theme.UnifiedPalette
  local t = context.transparency ---@type boolean

  local fg = c.text or u.fg1
  local fg_dim = c.textMuted or u.fg4
  local fg_soft = c.textDim or u.fg3
  local bg = t and c.none or (c.base or u.bg0)
  local bg_popup = t and c.none or (c.overlay or u.bg2)
  local border = c.border or u.bg3
  local success = c.success or c.accentGreen or c.brightGreen or u.brightGreen
  local warning = c.warning or c.accentYellow or c.brightYellow or u.brightYellow
  local danger = c.accentRed or c.tokenInvalid or c.brightRed or u.brightRed
  local info = c.accentBlue or c.brightBlue or u.brightBlue
  local selection_bg =
    c.selection
    or c.editor_inactiveSelectionBackground
    or c.editor_selectionHighlightBackground
    or c.tab_activeBackground
    or c.tab_selectedBackground
    or c.statusBar_background
    or cs.mix(bg, info, 20)
  local function mix_cursorline(base, accent, weight)
    if base == c.none then
      return base
    end
    return cs.mix(base, accent, weight)
  end
  local base_cursorline_bg =
    c.list_activeSelectionBackground
    or c.list_dropBackground
    or c.tab_activeBackground
    or c.tab_selectedBackground
    or c.menu_selectionBackground
    or c.dropdown_background
    or c.editor_selectionHighlightBackground
    or c.editor_inactiveSelectionBackground
    or selection_bg
  local cursorline_mix_target = c.menu_foreground or c.dropdown_foreground or fg
  local cursorline_bg = mix_cursorline(base_cursorline_bg, cursorline_mix_target, 42)
  if cursorline_bg == base_cursorline_bg then
    cursorline_bg = mix_cursorline(base_cursorline_bg, info, 28)
  end

  local item_kind_bg = c.none ---@type string

  ---@type table<string, std.t.theme.IHlgroup>
  return {
    ---! blink.cmp
    BlinkCmpDoc = { fg = fg, bg = bg_popup },
    BlinkCmpDocBorder = { fg = border, bg = bg_popup },
    BlinkCmpDocSeparator = { fg = fg_dim, bg = c.none },
    BlinkCmpGhostText = { fg = fg_dim, default = true },
    BlinkCmpItemIdx = { fg = fg_soft, bg = item_kind_bg },
    BlinkCmpKindClass = { fg = c.tokenTypesDeclarationAndReferences or c.accentBlue or info, bg = item_kind_bg },
    BlinkCmpKindCodeium = { fg = success, bg = item_kind_bg },
    BlinkCmpKindColor = { fg = c.tokenCssPropertyValue or fg, bg = item_kind_bg },
    BlinkCmpKindConstant = { fg = c.tokenConstantsAndEnums or c.accentOrange or warning, bg = item_kind_bg },
    BlinkCmpKindConstructor = { fg = c.tokenFunctionDeclarations or c.accentBlue or info, bg = item_kind_bg },
    BlinkCmpKindCopilot = { fg = success, bg = item_kind_bg },
    BlinkCmpKindDefault = { fg = fg_soft, bg = item_kind_bg },
    BlinkCmpKindEnum = { fg = c.tokenConstantsAndEnums or c.accentOrange or warning, bg = item_kind_bg },
    BlinkCmpKindEnumMember = { fg = c.tokenConstantsAndEnums or success, bg = item_kind_bg },
    BlinkCmpKindEvent = { fg = warning, bg = item_kind_bg },
    BlinkCmpKindField = { fg = c.tokenVariableAndParameterName or info, bg = item_kind_bg },
    BlinkCmpKindFile = { fg = fg, bg = item_kind_bg },
    BlinkCmpKindFolder = { fg = info, bg = item_kind_bg },
    BlinkCmpKindFunction = { fg = c.tokenFunctionDeclarations or info, bg = item_kind_bg },
    BlinkCmpKindIdentifier = { fg = c.tokenVariableAndParameterName or info, bg = item_kind_bg },
    BlinkCmpKindInterface = { fg = c.tokenTypesDeclarationAndReferences or info, bg = item_kind_bg },
    BlinkCmpKindKeyword = { fg = c.tokenKeyword or warning, bg = item_kind_bg },
    BlinkCmpKindMethod = { fg = c.tokenFunctionDeclarations or info, bg = item_kind_bg },
    BlinkCmpKindModule = { fg = c.tokenKeyword or warning, bg = item_kind_bg },
    BlinkCmpKindOperator = { fg = c.semanticNewOperator or fg, bg = item_kind_bg },
    BlinkCmpKindProperty = { fg = c.tokenObjectKeysTsGrammarSpecific or success, bg = item_kind_bg },
    BlinkCmpKindReference = { fg = c.tokenMarkupInlineRaw or info, bg = item_kind_bg },
    BlinkCmpKindSnippet = { fg = fg_dim, bg = item_kind_bg },
    BlinkCmpKindStruct = { fg = c.tokenTypesDeclarationAndReferences or warning, bg = item_kind_bg },
    BlinkCmpKindStructure = { fg = c.tokenTypesDeclarationAndReferences or warning, bg = item_kind_bg },
    BlinkCmpKindSupermaven = { fg = success, bg = item_kind_bg },
    BlinkCmpKindTabNine = { fg = success, bg = item_kind_bg },
    BlinkCmpKindText = { fg = c.tokenString or success, bg = item_kind_bg },
    BlinkCmpKindType = { fg = c.tokenTypesDeclarationAndReferences or info, bg = item_kind_bg },
    BlinkCmpKindTypeParameter = { fg = c.tokenTypesDeclarationAndReferences or info, bg = item_kind_bg },
    BlinkCmpKindUnit = { fg = c.tokenConstantsAndEnums or warning, bg = item_kind_bg },
    BlinkCmpKindValue = { fg = c.tokenConstantsAndEnums or success, bg = item_kind_bg },
    BlinkCmpKindVariable = { fg = c.tokenVariableAndParameterName or fg, bg = item_kind_bg },
    BlinkCmpLabel = { fg = fg, bg = item_kind_bg },
    BlinkCmpLabelDeprecated = { fg = fg_dim, bg = item_kind_bg, strikethrough = true },
    BlinkCmpLabelMatch = { fg = info, bg = item_kind_bg, bold = true },
    BlinkCmpMenu = { fg = fg, bg = bg_popup },
    BlinkCmpMenuBorder = { fg = border, bg = bg_popup },
    BlinkCmpSignatureHelp = { fg = fg, bg = bg_popup },
    BlinkCmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    BlinkCmpSignatureHelpBorder = { fg = border, bg = bg_popup },
    BlinkCmpSource = { fg = fg_soft, bg = item_kind_bg },

    ---! diffview.nvim
    DiffviewFilePanelDeletions = { fg = danger, bold = true },
    DiffviewFilePanelFileName = { fg = fg, bold = true },
    DiffviewFilePanelInsertions = { fg = success, bold = true },
    DiffviewStatusModified = { fg = info, bold = true },

    ---! flash.nvim
    FlashBackdrop = { fg = fg_dim },
    FlashCurrent = { fg = info, italic = true, bold = true },
    FlashLabel = { fg = bg, bg = c.accentPurple or info, bold = true },
    FlashMatch = { fg = warning, italic = true },
    FlashPrompt = { fg = fg, bg = cs.mix(bg_popup, border, 12) },
    FlashPromptIcon = { fg = c.accentOrange or warning, bg = c.none },

    ---! gitsigns.nvim
    GitSignsAdd = { fg = success },
    GitSignsAddNr = { link = "GitSignsAdd" },
    GitSignsChange = { fg = info },
    GitSignsChangeNr = { link = "GitSignsChange" },
    GitSignsDelete = { fg = danger },
    GitSignsDeleteNr = { link = "GitSignsDelete" },
    GitSignsTopdelete = { fg = danger },
    GitSignsTopdeleteNr = { link = "GitSignsTopdelete" },
    GitSignsUntracked = { fg = fg_dim },
    GitSignsUntrackedNr = { link = "GitSignsUntracked" },
    GitSignsCurrentLineBlame = { fg = fg_dim, italic = true },

    ---! lazy.nvim
    LazyButton = { fg = fg, bg = c.none },
    LazyButtonActive = { fg = bg, bg = info, bold = true },
    LazyCommit = { fg = success },
    LazyCommitIssue = { fg = warning },
    LazyDir = { fg = fg },
    LazyH1 = { fg = bg, bg = info, bold = true },
    LazyH2 = { fg = fg, bold = true, underline = true },
    LazyNoCond = { fg = danger },
    LazyNormal = { fg = fg, bg = cs.mix(bg, bg_popup, 70), blend = 40 },
    LazyProgressDone = { fg = info, bold = true },
    LazyProgressTodo = { fg = fg_dim, italic = true },
    LazyReasonCmd = { fg = warning },
    LazyReasonEvent = { fg = warning },
    LazyReasonFt = { fg = c.tokenMarkupHeading or info },
    LazyReasonImport = { fg = fg },
    LazyReasonKeys = { fg = info },
    LazyReasonPlugin = { fg = danger },
    LazyReasonRuntime = { fg = c.tokenKeyword or info },
    LazyReasonSource = { fg = success },
    LazyReasonStart = { fg = fg },
    LazyTaskOutput = { fg = fg },

    ---! mason.nvim
    MasonHeader = { fg = bg, bg = info },
    MasonHighlight = { fg = info },
    MasonHighlightBlock = { fg = bg, bg = success },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = fg_dim },
    MasonMutedBlock = { fg = fg_soft, bg = cs.mix(bg_popup, border, 8) },
    MasonNormal = { fg = fg, bg = cs.mix(bg, bg_popup, 70), blend = 40 },

    ---! mini.hipatterns
    MiniHipatternsFixme = { fg = bg, bg = danger, bold = true, italic = true, underline = true },
    MiniHipatternsHack = { fg = bg, bg = warning, bold = true, italic = true, underline = true },
    MiniHipatternsTodo = { fg = bg, bg = info, bold = true, italic = true, underline = true },
    MiniHipatternsNote = { fg = bg, bg = success, bold = true, italic = true, underline = true },

    ---! mini.indentscope
    MiniIndentscopeSymbol = { fg = info },
    MiniIndentscopeSymbolOff = { fg = warning },

    ---! neo-tree.nvim
    NeoTreeCursorLine = { fg = fg, bg = cursorline_bg },
    NeoTreeDirectoryIcon = { fg = info },
    NeoTreeDirectoryName = { fg = info },
    NeoTreeExpander = { fg = fg_dim },
    NeoTreeFileName = { fg = fg },
    NeoTreeGitIgnored = { fg = fg_dim },
    NeoTreeGitModified = { fg = warning },
    NeoTreeGitUntracked = { fg = success },
    NeoTreeIndentMarker = { fg = cs.mix(bg, border, 20) },
    NeoTreeNormal = { link = "Normal" },
    NeoTreeNormalNC = { link = "NormalNC" },
    NeoTreeRootName = { fg = fg, bold = true },
    NeoTreeSignColumn = { link = "SignColumn" },
    NeoTreeFloatBorder = { link = "FloatBorder" },
    NeoTreeTab = { fg = fg_dim, bg = c.none, bold = true },
    NeoTreeTabActive = { fg = bg, bg = info, bold = true },
    NeoTreeTabSeparator = { fg = c.none, bg = c.none },
    NeoTreeTabSeparatorActive = { fg = info, bg = c.none },
    NeoTreeStatusLine = { link = "StatusLine" },
    NeoTreeStatusLineNC = { link = "StatusLineNC" },
    NeoTreeVertSplit = { link = "VertSplit" },
    NeoTreeEndOfBuffer = { link = "EndOfBuffer" },
    NeoTreeWinSeparator = { link = "WinSeparator" },
    NeoTreeWinbar = { fg = fg_dim },

    ---! nvim-dap
    DapBreakpoint = { fg = danger },
    DapBreakpointCondition = { fg = warning },
    DapBreakpointRejected = { fg = fg_dim },
    DapLogPoint = { fg = info },
    DapStopped = { fg = c.accentOrange or warning },
    DapStoppedLine = { bg = cs.mix(bg, c.accentOrange or warning, 18), blend = 40 },

    ---! nvim-dap-ui
    DapUIBreakpointsCurrentLine = { fg = success, bold = true },
    DapUIBreakpointsDisabledLine = { fg = fg_dim },
    DapUIBreakpointsInfo = { fg = success },
    DapUIBreakpointsLine = { fg = info },
    DapUIBreakpointsPath = { fg = info, bold = true },
    DapUICurrentFrameName = { fg = success, bold = true },
    DapUIDecoration = { fg = info },
    DapUIFloatBorder = { fg = border, bg = bg_popup },
    DapUILineNumber = { fg = info },
    DapUIModifiedValue = { fg = warning },
    DapUIPlayPause = { fg = success },
    DapUIRestart = { fg = info },
    DapUIScope = { fg = info },
    DapUISource = { fg = c.tokenMarkupHeading or info },
    DapUIStepBack = { fg = warning },
    DapUIStepInto = { fg = info },
    DapUIStepOut = { fg = info },
    DapUIStepOver = { fg = info },
    DapUIStop = { fg = danger },
    DapUIStopNC = { fg = danger },
    DapUIThread = { fg = success },
  }
end

return M
