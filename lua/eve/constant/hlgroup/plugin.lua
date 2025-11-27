---@class eve.constant.hlgroup.plugin
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local md = string.format("eve.constant.hlgroup.%s.plugin", context.scheme.theme) ---@type string
  local ok, mod = pcall(require, md)
  if ok and mod then
    return mod.gen_hlgroup_map(context)
  end

  return M.default_gen_hlgroup_map(context)
end

function M.default_gen_hlgroup_map(context)
  local cs = std.color
  local c = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette
  local t = context.transparency ---@type boolean

  local item_kind_bg = c.none ---@type string
  local cmp_panel_bg = cs.mix(c.bg0, c.bg2, 75) ---@type string
  local treesitter_context_bg = t and c.none or cs.mix(c.bg0, c.brightBlue, 65) ---@type string
  local lazy_badge_fg = c.bg1 ---@type string
  local lazy_badge_bg = c.pink ---@type string

  ---@type table<string, std.t.theme.IHlgroup>
  return {
    ---! cmp
    BlinkCmpDoc = { bg = cmp_panel_bg },
    BlinkCmpDocBorder = { fg = c.bg4, bg = cmp_panel_bg },
    BlinkCmpDocSeparator = { fg = c.bg4, bg = cmp_panel_bg },
    BlinkCmpGhostText = { link = "Comment", default = true },
    BlinkCmpItemIdx = { fg = c.fg3, bg = item_kind_bg },
    BlinkCmpKindClass = { fg = c.aqua, bg = item_kind_bg },
    BlinkCmpKindCodeium = { fg = c.green, bg = item_kind_bg },
    BlinkCmpKindColor = { fg = c.fg1, bg = item_kind_bg },
    BlinkCmpKindConstant = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindConstructor = { fg = c.blue, bg = item_kind_bg },
    BlinkCmpKindCopilot = { fg = c.green, bg = item_kind_bg },
    BlinkCmpKindDefault = { fg = c.fg2, bg = item_kind_bg },
    BlinkCmpKindEnum = { fg = c.blue, bg = item_kind_bg },
    BlinkCmpKindEnumMember = { fg = c.purple, bg = item_kind_bg },
    BlinkCmpKindEvent = { fg = c.yellow, bg = item_kind_bg },
    BlinkCmpKindField = { fg = c.red, bg = item_kind_bg },
    BlinkCmpKindFile = { fg = c.fg1, bg = item_kind_bg },
    BlinkCmpKindFolder = { fg = c.fg1, bg = item_kind_bg },
    BlinkCmpKindFunction = { fg = c.blue, bg = item_kind_bg },
    BlinkCmpKindIdentifier = { fg = c.red, bg = item_kind_bg },
    BlinkCmpKindInterface = { fg = c.green, bg = item_kind_bg },
    BlinkCmpKindKeyword = { fg = c.fg1, bg = item_kind_bg },
    BlinkCmpKindMethod = { fg = c.blue, bg = item_kind_bg },
    BlinkCmpKindModule = { fg = c.yellow, bg = item_kind_bg },
    BlinkCmpKindOperator = { fg = c.fg1, bg = item_kind_bg },
    BlinkCmpKindProperty = { fg = c.red, bg = item_kind_bg },
    BlinkCmpKindReference = { fg = c.fg1, bg = item_kind_bg },
    BlinkCmpKindSnippet = { fg = c.red, bg = item_kind_bg },
    BlinkCmpKindStruct = { fg = c.purple, bg = item_kind_bg },
    BlinkCmpKindStructure = { fg = c.purple, bg = item_kind_bg },
    BlinkCmpKindSupermaven = { fg = c.green, bg = item_kind_bg },
    BlinkCmpKindTabNine = { fg = c.orange, bg = item_kind_bg },
    BlinkCmpKindText = { fg = c.green, bg = item_kind_bg },
    BlinkCmpKindType = { fg = c.yellow, bg = item_kind_bg },
    BlinkCmpKindTypeParameter = { fg = c.red, bg = item_kind_bg },
    BlinkCmpKindUnit = { fg = c.purple, bg = item_kind_bg },
    BlinkCmpKindValue = { fg = c.aqua, bg = item_kind_bg },
    BlinkCmpKindVariable = { fg = c.purple, bg = item_kind_bg },
    BlinkCmpLabel = { fg = c.fg4, italic = true, bg = item_kind_bg },
    BlinkCmpLabelDeprecated = { fg = c.bg4, italic = true, bg = item_kind_bg, strikethrough = true },
    BlinkCmpLabelMatch = { fg = c.blue, italic = true, bg = item_kind_bg },
    BlinkCmpMenu = { fg = c.fg4, italic = true, bg = cmp_panel_bg },
    BlinkCmpMenuBorder = { fg = c.bg4, bg = cmp_panel_bg },
    BlinkCmpSignatureHelp = { bg = cmp_panel_bg },
    BlinkCmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    BlinkCmpSignatureHelpBorder = { fg = c.bg4, bg = cmp_panel_bg },
    BlinkCmpSource = { fg = c.fg3, bg = item_kind_bg },

    ---! diffview.nvim
    DiffviewFilePanelDeletions = { fg = c.red, bold = true },
    DiffviewFilePanelFileName = { fg = c.fg2, bold = true },
    DiffviewFilePanelInsertions = { fg = c.green, bold = true },
    DiffviewStatusModified = { fg = c.green, bold = true },

    ---! flash.nvim
    FlashBackdrop = { fg = c.bg4, bg = c.none },
    FlashCurrent = { fg = c.bg0, bg = c.orange, bold = true },
    FlashLabel = { fg = c.bg0, bg = c.pink, bold = true },
    FlashMatch = { fg = c.bg0, bg = c.aqua, bold = true },
    FlashPrompt = { fg = c.yellow, bg = c.bg2 },
    FlashPromptIcon = { fg = c.orange, bg = c.none },
    FlashCursor = { fg = c.bg0, bg = c.fg1 },

    ---! gitsigns.nvim
    GitSignsAdd = { fg = c.green },
    GitSignsAddNr = { link = "GitSignsAdd" },
    GitSignsChange = { fg = c.blue },
    GitSignsChangeNr = { link = "GitSignsChange" },
    GitSignsDelete = { fg = c.red },
    GitSignsDeleteNr = { link = "GitSignsDelete" },
    GitSignsTopdelete = { fg = c.red },
    GitSignsTopdeleteNr = { link = "GitSignsTopdelete" },
    GitSignsUntracked = { fg = c.grey },
    GitSignsUntrackedNr = { link = "GitSignsUntracked" },
    GitSignsStagedAdd = { fg = cs.mix(c.bg0, c.green, 50) },
    GitSignsStagedAddNr = { link = "GitSignsStagedAdd" },
    GitSignsStagedChange = { fg = cs.mix(c.bg0, c.blue, 50) },
    GitSignsStagedChangeNr = { link = "GitSignsStagedChange" },
    GitSignsStagedDelete = { fg = cs.mix(c.bg0, c.red, 50) },
    GitSignsStagedDeleteNr = { link = "GitSignsStagedDelete" },
    GitSignsStagedTopdelete = { fg = cs.mix(c.bg0, c.red, 50) },
    GitSignsStagedTopdeleteNr = { link = "GitSignsStagedTopdelete" },
    GitSignsStagedUntracked = { fg = cs.mix(c.bg0, c.grey, 50) },
    GitSignsStagedUntrackedNr = { link = "GitSignsStagedUntracked" },
    GitSignsCurrentLineBlame = { fg = c.bg4, italic = true },

    ---! lazy.nvim
    LazyButton = { fg = c.fg2, bg = c.none },
    LazyButtonActive = { fg = c.pink, bg = c.none },
    LazyCommit = { fg = c.green },
    LazyCommitIssue = { fg = c.orange },
    LazyDir = { fg = c.fg1 },
    LazyH1 = { fg = lazy_badge_fg, bg = lazy_badge_bg, bold = true },
    LazyH2 = { fg = c.fg2, bold = true, underline = true },
    LazyNoCond = { fg = c.red },
    LazyNormal = { bg = cs.mix(c.bg0, c.bg1, 80), blend = 50 },
    LazyOperator = { fg = c.fg1 },
    LazyProp = { fg = c.pink, bold = true },
    LazyProgressDone = { fg = c.green },
    LazyProgressTodo = { fg = c.bg4, italic = true },
    LazyReasonCmd = { fg = c.yellow },
    LazyReasonEvent = { fg = c.yellow },
    LazyReasonFt = { fg = c.purple },
    LazyReasonImport = { fg = c.fg1 },
    LazyReasonKeys = { fg = c.brightAqua },
    LazyReasonPlugin = { fg = c.red },
    LazyReasonRuntime = { fg = c.purple },
    LazyReasonSource = { fg = c.aqua },
    LazyReasonStart = { fg = c.fg1 },
    LazySpecial = { fg = c.blue },
    LazyTaskOutput = { fg = c.fg1 },
    LazyUrl = { fg = c.fg1 },
    LazyValue = { fg = c.brightAqua },

    ---! mason.nvim
    MasonHeader = { fg = c.pink, bg = c.none },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = lazy_badge_fg, bg = lazy_badge_bg, bold = true },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = c.fg1 },
    MasonMutedBlock = { fg = c.fg1 },
    MasonNormal = { fg = c.fg1, bg = cs.mix(c.bg0, c.bg1, 60), blend = 50 },

    ---! mini.icons
    MiniIconsAzure = { fg = c.brightBlue },
    MiniIconsBlue = { fg = c.brightBlue },
    MiniIconsCyan = { fg = c.brightAqua },
    MiniIconsGreen = { fg = c.brightGreen },
    MiniIconsGrey = { fg = c.fg2 },
    MiniIconsOrange = { fg = c.brightOrange },
    MiniIconsPurple = { fg = c.brightPurple },
    MiniIconsRed = { fg = c.brightRed },
    MiniIconsYellow = { fg = c.brightYellow },

    ---! neo-tree.nvim
    NeoTreeCursorLine = { bg = c.bg2 },
    NeoTreeDirectoryIcon = { link = "Directory" },
    NeoTreeDirectoryName = { fg = c.brightBlue },
    NeoTreeExpander = { fg = c.fg4 },
    NeoTreeFileName = { fg = c.fg2 },
    NeoTreeFloatBorder = { link = "FloatBorder" },
    NeoTreeFloatTitle = { link = "FloatTitle" },
    NeoTreeGitIgnored = { fg = c.fg4 },
    NeoTreeGitModified = { fg = c.brightYellow },
    NeoTreeGitUntracked = { fg = c.brightOrange },
    NeoTreeHiddenByName = { fg = c.fg4 },
    NeoTreeIndentMarker = { fg = c.bg2 },
    NeoTreeMessage = { fg = c.grey },
    NeoTreeNormal = { link = "Normal" },
    NeoTreeNormalNC = { link = "NormalNC" },
    NeoTreeRootName = { fg = c.fg1, bold = true },
    NeoTreeTab = { fg = c.fg4, bg = c.none, bold = true },
    NeoTreeTabActive = { fg = c.bg1, bg = c.aqua, bold = true },
    NeoTreeTabSeparator = { fg = c.none, bg = c.none },
    NeoTreeTabSeparatorActive = { fg = c.aqua, bg = c.none },
    NeoTreeTitleBar = { fg = c.fg4 },
    NeoTreeWinbar = { fg = c.none, bg = c.none },

    ---! nvim-dap
    DapBreakpoint = { fg = c.red },
    DapBreakpointCondition = { fg = c.yellow },
    DapBreakpointRejected = { fg = c.fg4 },
    DapLogPoint = { fg = c.aqua },
    DapStopped = { fg = c.orange },
    DapStoppedLine = { bg = cs.mix(c.bg0, c.yellow, 40), blend = 50, reverse = false },

    ---! nvim-dap-ui
    DapUIBreakpointsCurrentLine = { fg = c.green, bold = true },
    DapUIBreakpointsDisabledLine = { fg = c.fg4 },
    DapUIBreakpointsInfo = { fg = c.green },
    DapUIBreakpointsLine = { fg = c.aqua },
    DapUIBreakpointsPath = { fg = c.aqua },
    DapUICurrentFrameName = { fg = c.green, bold = true },
    DapUIDecoration = { fg = c.aqua },
    DapUIEndofBuffer = { link = "EndofBuffer" },
    DapUIFloatBorder = { link = "FloatBorder" },
    DapUIFloatNormal = { link = "NormalFloat" },
    DapUIFrameName = { link = "Normal" },
    DapUILineNumber = { fg = c.aqua },
    DapUIModifiedValue = { fg = c.orange },
    DapUINormal = { link = "Normal" },
    DapUIPlayPause = { fg = c.green },
    DapUIPlayPauseNC = { fg = c.green },
    DapUIRestart = { fg = c.green },
    DapUIRestartNC = { fg = c.green },
    DapUIScope = { fg = c.aqua },
    DapUISource = { fg = c.purple },
    DapUIStepBack = { fg = c.aqua },
    DapUIStepBackNC = { fg = c.blue },
    DapUIStepInto = { fg = c.aqua },
    DapUIStepIntoNC = { fg = c.blue },
    DapUIStepOut = { fg = c.aqua },
    DapUIStepOutNC = { fg = c.blue },
    DapUIStepOver = { fg = c.aqua },
    DapUIStepOverNC = { fg = c.blue },
    DapUIStop = { fg = c.red },
    DapUIStopNC = { fg = c.red },
    DapUIStoppedThread = { fg = c.aqua },
    DapUIThread = { fg = c.green },
    DapUIType = { fg = c.purple },
    DapUIUnavailable = { fg = c.fg4 },
    DapUIUnavailableNC = { fg = c.fg4 },
    DapUIValue = { fg = c.aqua },
    DapUIVariable = { fg = c.fg1 },
    DapUIWatchesEmpty = { fg = c.red },
    DapUIWatchesError = { fg = c.red },
    DapUIWatchesValue = { fg = c.green },
    DapUIWinSelect = { fg = c.aqua, bold = true },

    ---! nvim-dap-virtual-text
    NvimDapVirtualText = { fg = c.fg2, bg = cs.mix(c.bg0, c.orange, 30), italic = true },
    NvimDapVirtualTextChanged = { fg = c.fg0, bg = cs.mix(c.bg0, c.orange, 30), italic = true },

    NotifyERRORIcon = { fg = c.red },
    NotifyWARNIcon = { fg = c.yellow },
    NotifyINFOIcon = { fg = c.green },
    NotifyDEBUGIcon = { fg = c.orange },
    NotifyTRACEIcon = { fg = c.bg4 },

    NotifyERRORTitle = { link = "NotifyERRORIcon" },
    NotifyWARNTitle = { link = "NotifyWARNIcon" },
    NotifyINFOTitle = { link = "NotifyINFOIcon" },
    NotifyDEBUGTitle = { link = "NotifyDEBUGIcon" },
    NotifyTRACETitle = { link = "NotifyTRACEIcon" },

    ---! nvim-treesitter-context
    TreesitterContext = { fg = c.fg1, bg = treesitter_context_bg },
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
    SnacksPickerLabel = { fg = c.brightBlue, bold = true },
    SnacksPickerFile = { fg = c.brightAqua },

    ---! which-key.nvim
    WhichKey = { fg = c.blue },
    WhichKeyDesc = { fg = c.fg3 },
    WhichKeyGroup = { fg = c.blue },
    WhichKeyIconAzure = { fg = c.blue },
    WhichKeyIconBlue = { fg = c.blue },
    WhichKeyIconCyan = { fg = c.aqua },
    WhichKeyIconGreen = { fg = c.green },
    WhichKeyIconGrey = { fg = c.bg4 },
    WhichKeyIconOrange = { fg = c.orange },
    WhichKeyIconPurple = { fg = c.purple },
    WhichKeyIconRed = { fg = c.red },
    WhichKeyIconYellow = { fg = c.yellow },
    WhichKeyNormal = { fg = c.fg1, bg = t and c.none or c.bg2 },
    WhichKeySeparator = { fg = c.bg4 },
    WhichKeyValue = { fg = c.green },
  }
end

return M
