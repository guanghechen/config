---@class eve.constant.hlgroup.tokyonight.plugin
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = std.color
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.tokyonight ---@type std.t.theme.TokyonightPalette
  local u = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette
  local item_kind_bg = c.none ---@type string
  local cmp_panel_bg = cs.mix(c.bg_dark, c.bg, 80) ---@type string
  local treesitter_context_bg = t and c.none or cs.mix(c.bg_dark, c.blue1, 70) ---@type string
  local lazy_badge_fg = u.bg1 ---@type string
  local lazy_badge_bg = u.pink ---@type string

  ---@type table<string, std.t.theme.IHlgroup>
  local hlgroup_map = {
    ---! blink.cmp
    BlinkCmpDoc = { fg = c.fg, bg = cmp_panel_bg },
    BlinkCmpDocBorder = { fg = c.border_highlight, bg = cmp_panel_bg },
    BlinkCmpDocSeparator = { fg = c.dark3, bg = cmp_panel_bg },
    BlinkCmpGhostText = { fg = c.terminal_black, default = true },
    BlinkCmpItemIdx = { fg = c.dark5, bg = item_kind_bg },
    BlinkCmpKindClass = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindCodeium = { fg = c.teal, bg = item_kind_bg },
    BlinkCmpKindColor = { fg = c.fg, bg = item_kind_bg },
    BlinkCmpKindConstant = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindConstructor = { fg = c.magenta, bg = item_kind_bg },
    BlinkCmpKindCopilot = { fg = c.teal, bg = item_kind_bg },
    BlinkCmpKindDefault = { fg = c.fg_dark, bg = item_kind_bg },
    BlinkCmpKindEnum = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindEnumMember = { fg = c.teal, bg = item_kind_bg },
    BlinkCmpKindEvent = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindField = { fg = c.green1, bg = item_kind_bg },
    BlinkCmpKindFile = { fg = c.fg, bg = item_kind_bg },
    BlinkCmpKindFolder = { fg = c.blue, bg = item_kind_bg },
    BlinkCmpKindFunction = { fg = c.blue, bg = item_kind_bg },
    BlinkCmpKindIdentifier = { fg = c.magenta, bg = item_kind_bg },
    BlinkCmpKindInterface = { fg = cs.mix(c.bg, c.blue1, 80), bg = item_kind_bg },
    BlinkCmpKindKeyword = { fg = c.cyan, bg = item_kind_bg },
    BlinkCmpKindMethod = { fg = c.blue, bg = item_kind_bg },
    BlinkCmpKindModule = { fg = c.yellow, bg = item_kind_bg },
    BlinkCmpKindOperator = { fg = c.blue5, bg = item_kind_bg },
    BlinkCmpKindProperty = { fg = c.green1, bg = item_kind_bg },
    BlinkCmpKindReference = { fg = c.teal, bg = item_kind_bg },
    BlinkCmpKindSnippet = { fg = c.dark5, bg = item_kind_bg },
    BlinkCmpKindStruct = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindStructure = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindSupermaven = { fg = c.teal, bg = item_kind_bg },
    BlinkCmpKindTabNine = { fg = c.teal, bg = item_kind_bg },
    BlinkCmpKindText = { fg = c.green, bg = item_kind_bg },
    BlinkCmpKindType = { fg = c.blue1, bg = item_kind_bg },
    BlinkCmpKindTypeParameter = { fg = c.teal, bg = item_kind_bg },
    BlinkCmpKindUnit = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindValue = { fg = c.green, bg = item_kind_bg },
    BlinkCmpKindVariable = { fg = c.fg, bg = item_kind_bg },
    BlinkCmpLabel = { fg = c.fg, bg = item_kind_bg },
    BlinkCmpLabelDeprecated = { fg = c.fg_gutter, bg = item_kind_bg, strikethrough = true },
    BlinkCmpLabelMatch = { fg = c.blue1, bg = item_kind_bg },
    BlinkCmpMenu = { fg = c.fg, bg = cmp_panel_bg },
    BlinkCmpMenuBorder = { fg = c.border_highlight, bg = cmp_panel_bg },
    BlinkCmpSignatureHelp = { fg = c.fg, bg = cmp_panel_bg },
    BlinkCmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    BlinkCmpSignatureHelpBorder = { fg = c.border_highlight, bg = cmp_panel_bg },
    BlinkCmpSource = { fg = c.dark5, bg = item_kind_bg },

    ---! diffview.nvim
    DiffviewFilePanelDeletions = { fg = c.red, bold = true },
    DiffviewFilePanelFileName = { fg = c.fg, bold = true },
    DiffviewFilePanelInsertions = { fg = c.green, bold = true },
    DiffviewStatusModified = { fg = c.git_change, bold = true },

    ---! flash.nvim
    FlashBackdrop = { fg = c.dark3 },
    FlashCurrent = { fg = c.orange, bg = c.none, italic = true },
    FlashLabel = { bg = c.magenta2, bold = true, fg = c.fg },
    FlashMatch = { fg = c.blue1, bg = c.none, italic = true },
    FlashPrompt = { fg = c.yellow, bg = c.bg_highlight },
    FlashPromptIcon = { fg = c.orange, bg = c.none },

    ---! gitsigns.nvim
    GitSignsAdd = { fg = c.git_add },
    GitSignsAddNr = { link = "GitSignsAdd" },
    GitSignsChange = { fg = c.git_change },
    GitSignsChangeNr = { link = "GitSignsChange" },
    GitSignsDelete = { fg = c.git_delete },
    GitSignsDeleteNr = { link = "GitSignsDelete" },
    GitSignsTopdelete = { fg = c.git_delete },
    GitSignsTopdeleteNr = { link = "GitSignsTopdelete" },
    GitSignsUntracked = { fg = c.dark3 },
    GitSignsUntrackedNr = { link = "GitSignsUntracked" },
    GitSignsStagedAdd = { fg = cs.mix(c.bg, c.git_add, 50) },
    GitSignsStagedAddNr = { link = "GitSignsStagedAdd" },
    GitSignsStagedChange = { fg = cs.mix(c.bg, c.git_change, 50) },
    GitSignsStagedChangeNr = { link = "GitSignsStagedChange" },
    GitSignsStagedDelete = { fg = cs.mix(c.bg, c.git_delete, 50) },
    GitSignsStagedDeleteNr = { link = "GitSignsStagedDelete" },
    GitSignsStagedTopdelete = { fg = cs.mix(c.bg, c.git_delete, 50) },
    GitSignsStagedTopdeleteNr = { link = "GitSignsStagedTopdelete" },
    GitSignsStagedUntracked = { fg = cs.mix(c.bg, c.dark3, 50) },
    GitSignsStagedUntrackedNr = { link = "GitSignsStagedUntracked" },
    GitSignsCurrentLineBlame = { fg = c.dark3, italic = true },

    ---! lazy.nvim
    LazyButton = { fg = c.fg_dark, bg = c.none },
    LazyButtonActive = { fg = u.pink, bg = c.none },
    LazyCommit = { fg = c.green },
    LazyCommitIssue = { fg = c.orange },
    LazyDir = { fg = c.fg },
    LazyH1 = { fg = lazy_badge_fg, bg = lazy_badge_bg, bold = true },
    LazyH2 = { fg = c.fg, bold = true, underline = true },
    LazyNoCond = { fg = c.red },
    LazyNormal = { bg = t and c.none or cs.mix(c.bg, c.bg_dark, 80), blend = 50 },
    LazyOperator = { fg = c.fg },
    LazyProp = { fg = c.magenta2, bold = true },
    LazyProgressDone = { fg = c.magenta2, bold = true },
    LazyProgressTodo = { fg = c.fg_gutter, bold = true },
    LazyReasonCmd = { fg = c.yellow },
    LazyReasonEvent = { fg = c.yellow },
    LazyReasonFt = { fg = c.purple },
    LazyReasonImport = { fg = c.fg },
    LazyReasonKeys = { fg = c.teal },
    LazyReasonPlugin = { fg = c.red },
    LazyReasonRuntime = { fg = c.purple },
    LazyReasonSource = { fg = c.cyan },
    LazyReasonStart = { fg = c.fg },
    LazySpecial = { fg = c.blue },
    LazyTaskOutput = { fg = c.fg },
    LazyUrl = { fg = c.fg },
    LazyValue = { fg = c.teal },

    ---! mason.nvim
    MasonHeader = { fg = u.pink, bg = c.none },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = lazy_badge_fg, bg = lazy_badge_bg, bold = true },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = u.fg1 },
    MasonMutedBlock = { fg = u.fg1 },
    MasonNormal = { fg = c.fg, bg = t and c.none or cs.mix(c.bg, c.bg_dark, 60), blend = 50 },

    ---! mini.icons
    MiniIconsAzure = { fg = c.info },
    MiniIconsBlue = { fg = c.blue },
    MiniIconsCyan = { fg = c.teal },
    MiniIconsGreen = { fg = c.green },
    MiniIconsGrey = { fg = c.fg },
    MiniIconsOrange = { fg = c.orange },
    MiniIconsPurple = { fg = c.purple },
    MiniIconsRed = { fg = c.red },
    MiniIconsYellow = { fg = c.yellow },

    ---! mini.indentscope
    MiniIndentscopeSymbol = { fg = c.pink },
    MiniIndentscopeSymbolOff = { fg = c.warning },

    ---! neo-tree.nvim
    NeoTreeCursorLine = { bg = c.bg_highlight },
    NeoTreeDirectoryIcon = { link = "Directory" },
    NeoTreeDirectoryName = { fg = c.blue },
    NeoTreeExpander = { fg = c.dark5 },
    NeoTreeFileName = { fg = c.fg },
    NeoTreeFloatBorder = { link = "FloatBorder" },
    NeoTreeFloatTitle = { link = "FloatTitle" },
    NeoTreeGitIgnored = { fg = c.dark5 },
    NeoTreeGitModified = { fg = c.warning },
    NeoTreeGitUntracked = { fg = c.orange },
    NeoTreeHiddenByName = { fg = c.dark5 },
    NeoTreeIndentMarker = { fg = c.bg_highlight },
    NeoTreeMessage = { fg = c.dark3 },
    NeoTreeNormal = { link = "Normal" },
    NeoTreeNormalNC = { link = "NormalNC" },
    NeoTreeRootName = { fg = c.fg, bold = true },
    NeoTreeTab = { fg = c.dark5, bg = c.none, bold = true },
    NeoTreeTabActive = { fg = c.bg, bg = c.blue, bold = true },
    NeoTreeTabSeparator = { fg = c.none, bg = c.none },
    NeoTreeTabSeparatorActive = { fg = c.blue, bg = c.none },
    NeoTreeTitleBar = { fg = c.dark5 },
    NeoTreeWinbar = { fg = c.none, bg = c.none },

    ---! nvim-dap
    DapBreakpoint = { fg = c.red },
    DapBreakpointCondition = { fg = c.warning },
    DapBreakpointRejected = { fg = c.dark5 },
    DapLogPoint = { fg = c.info },
    DapStopped = { fg = c.orange },
    DapStoppedLine = { bg = cs.mix(c.bg, c.warning, 10), blend = 50, reverse = false },

    ---! nvim-dap-ui
    DapUIBreakpointsCurrentLine = { fg = c.green, bold = true },
    DapUIBreakpointsDisabledLine = { fg = c.dark5 },
    DapUIBreakpointsInfo = { fg = c.green },
    DapUIBreakpointsLine = { fg = c.cyan },
    DapUIBreakpointsPath = { fg = c.cyan },
    DapUICurrentFrameName = { fg = c.green, bold = true },
    DapUIDecoration = { fg = c.cyan },
    DapUIEndofBuffer = { link = "EndofBuffer" },
    DapUIFloatBorder = { link = "FloatBorder" },
    DapUIFloatNormal = { link = "NormalFloat" },
    DapUIFrameName = { link = "Normal" },
    DapUILineNumber = { fg = c.cyan },
    DapUIModifiedValue = { fg = c.orange },
    DapUINormal = { link = "Normal" },
    DapUIPlayPause = { fg = c.green },
    DapUIPlayPauseNC = { fg = c.green },
    DapUIRestart = { fg = c.green },
    DapUIRestartNC = { fg = c.green },
    DapUIScope = { fg = c.cyan },
    DapUISource = { fg = c.purple },
    DapUIStepBack = { fg = c.cyan },
    DapUIStepBackNC = { fg = c.blue },
    DapUIStepInto = { fg = c.cyan },
    DapUIStepIntoNC = { fg = c.blue },
    DapUIStepOut = { fg = c.cyan },
    DapUIStepOutNC = { fg = c.blue },
    DapUIStepOver = { fg = c.cyan },
    DapUIStepOverNC = { fg = c.blue },
    DapUIStop = { fg = c.red },
    DapUIStopNC = { fg = c.red },
    DapUIStoppedThread = { fg = c.cyan },
    DapUIThread = { fg = c.green },
    DapUIType = { fg = c.purple },
    DapUIUnavailable = { fg = c.dark5 },
    DapUIUnavailableNC = { fg = c.dark5 },
    DapUIValue = { fg = c.cyan },
    DapUIVariable = { fg = c.fg },
    DapUIWatchesEmpty = { fg = c.red },
    DapUIWatchesError = { fg = c.red },
    DapUIWatchesValue = { fg = c.green },
    DapUIWinSelect = { fg = c.cyan, bold = true },

    ---! nvim-dap-virtual-text
    NvimDapVirtualText = { fg = c.fg_dark, bg = cs.mix(c.bg, c.orange, 30), italic = true },
    NvimDapVirtualTextChanged = { fg = c.fg, bg = cs.mix(c.bg, c.orange, 30), italic = true },

    ---! nvim-notify
    NotifyERRORIcon = { fg = c.red },
    NotifyWARNIcon = { fg = c.warning },
    NotifyINFOIcon = { fg = c.info },
    NotifyDEBUGIcon = { fg = c.hint },
    NotifyTRACEIcon = { fg = c.dark3 },

    NotifyERRORTitle = { link = "NotifyERRORIcon" },
    NotifyWARNTitle = { link = "NotifyWARNIcon" },
    NotifyINFOTitle = { link = "NotifyINFOIcon" },
    NotifyDEBUGTitle = { link = "NotifyDEBUGIcon" },
    NotifyTRACETitle = { link = "NotifyTRACEIcon" },

    ---! nvim-treesitter-context
    TreesitterContext = { fg = c.fg, bg = treesitter_context_bg },
    TreesitterContextBottom = {},
    TreesitterContextLineNumber = { fg = c.orange, bg = treesitter_context_bg },
    TreesitterContextLineNumberBottom = { underline = true },

    ---! sidekick.nvim
    SidekickCliAttach = { link = "NormalFloat" },
    SidekickCliFailed = { link = "DiagnosticError" },
    SidekickCliStarted = { link = "DiagnosticOk" },
    SidekickDiffAdd = { link = "DiffWordRight" },
    SidekickDiffDelete = { link = "DiffWordLeft" },
    SidekickLocDelim = { link = "Delimiter" },
    SidekickLocFile = { fg = c.blue },
    SidekickLocRow = { fg = c.orange },

    ---! snacks.nvim
    SnacksPickerLabel = { fg = c.blue, bold = true },
    SnacksPickerFile = { fg = c.cyan },

    ---! which-key.nvim
    WhichKey = { fg = c.cyan },
    WhichKeyDesc = { fg = c.magenta },
    WhichKeyGroup = { fg = c.blue },
    WhichKeyIconAzure = { fg = c.info },
    WhichKeyIconBlue = { fg = c.blue },
    WhichKeyIconCyan = { fg = c.cyan },
    WhichKeyIconGreen = { fg = c.green },
    WhichKeyIconGrey = { fg = c.dark3 },
    WhichKeyIconOrange = { fg = c.orange },
    WhichKeyIconPurple = { fg = c.purple },
    WhichKeyIconRed = { fg = c.red },
    WhichKeyIconYellow = { fg = c.yellow },
    WhichKeyNormal = { fg = c.fg, bg = t and c.none or c.bg_dark },
    WhichKeySeparator = { fg = c.comment },
    WhichKeyValue = { fg = c.dark5 },
  }

  return hlgroup_map
end

return M
