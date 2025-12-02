---@class eve.constant.hlgroup.catppuccin.plugin
local M = {}

---@param context                       std.t.theme.IContext
---@return table<string, std.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.catppuccin ---@type std.t.theme.CatppuccinPalette
  local u = context.scheme.palette.unified ---@type std.t.theme.UnifiedPalette
  local mix = std.color.mix
  local cmp_panel_bg = mix(t and c.none or c.mantle, c.surface0, 65)
  local lazy_panel_bg = mix(t and c.none or c.mantle, c.surface1, 60)
  local dap_virtual_bg = mix(t and c.none or c.surface0, c.peach, 25)
  local treesitter_context_bg = t and c.none or mix(c.base, c.sapphire, 65)
  local indent_marker_fg = mix(t and c.none or c.surface0, c.overlay0, 30)
  local lazy_badge_fg = u.bg1 ---@type string
  local lazy_badge_bg = u.pink ---@type string

  local function staged_color(accent)
    return mix(accent, c.subtext0, 35)
  end

  ---@type table<string, std.t.theme.IHlgroup>
  return {
    ---! blink.cmp
    BlinkCmpDoc = { fg = c.text, bg = cmp_panel_bg },
    BlinkCmpDocBorder = { fg = c.overlay1, bg = cmp_panel_bg },
    BlinkCmpDocSeparator = { fg = c.overlay0, bg = cmp_panel_bg },
    BlinkCmpGhostText = { fg = c.overlay1, default = true },
    BlinkCmpItemIdx = { fg = c.overlay2, bg = c.none },
    BlinkCmpKindClass = { fg = c.yellow, bg = c.none },
    BlinkCmpKindCodeium = { fg = c.teal, bg = c.none },
    BlinkCmpKindColor = { fg = c.pink, bg = c.none },
    BlinkCmpKindConstant = { fg = c.peach, bg = c.none },
    BlinkCmpKindConstructor = { fg = c.blue, bg = c.none },
    BlinkCmpKindCopilot = { fg = c.teal, bg = c.none },
    BlinkCmpKindDefault = { fg = c.overlay2, bg = c.none },
    BlinkCmpKindEnum = { fg = c.yellow, bg = c.none },
    BlinkCmpKindEnumMember = { fg = c.red, bg = c.none },
    BlinkCmpKindEvent = { fg = c.sky, bg = c.none },
    BlinkCmpKindField = { fg = c.green, bg = c.none },
    BlinkCmpKindFile = { fg = c.blue, bg = c.none },
    BlinkCmpKindFolder = { fg = c.blue, bg = c.none },
    BlinkCmpKindFunction = { fg = c.blue, bg = c.none },
    BlinkCmpKindIdentifier = { fg = c.flamingo, bg = c.none },
    BlinkCmpKindInterface = { fg = c.lavender, bg = c.none },
    BlinkCmpKindKeyword = { fg = c.mauve, bg = c.none },
    BlinkCmpKindMethod = { fg = c.blue, bg = c.none },
    BlinkCmpKindModule = { fg = c.blue, bg = c.none },
    BlinkCmpKindOperator = { fg = c.sky, bg = c.none },
    BlinkCmpKindProperty = { fg = c.green, bg = c.none },
    BlinkCmpKindReference = { fg = c.red, bg = c.none },
    BlinkCmpKindSnippet = { fg = c.mauve, bg = c.none },
    BlinkCmpKindStruct = { fg = c.lavender, bg = c.none },
    BlinkCmpKindStructure = { fg = c.lavender, bg = c.none },
    BlinkCmpKindSupermaven = { fg = c.teal, bg = c.none },
    BlinkCmpKindTabNine = { fg = c.teal, bg = c.none },
    BlinkCmpKindText = { fg = c.teal, bg = c.none },
    BlinkCmpKindType = { fg = c.lavender, bg = c.none },
    BlinkCmpKindTypeParameter = { fg = c.lavender, bg = c.none },
    BlinkCmpKindUnit = { fg = c.green, bg = c.none },
    BlinkCmpKindValue = { fg = c.peach, bg = c.none },
    BlinkCmpKindVariable = { fg = c.flamingo, bg = c.none },
    BlinkCmpLabel = { fg = c.text, bg = c.none },
    BlinkCmpLabelDeprecated = { fg = c.overlay1, bg = c.none, strikethrough = true },
    BlinkCmpLabelMatch = { fg = c.blue, bg = c.none, bold = true },
    BlinkCmpMenu = { fg = c.text, bg = cmp_panel_bg },
    BlinkCmpMenuBorder = { fg = c.overlay1, bg = cmp_panel_bg },
    BlinkCmpSignatureHelp = { fg = c.text, bg = cmp_panel_bg },
    BlinkCmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    BlinkCmpSignatureHelpBorder = { fg = c.overlay1, bg = cmp_panel_bg },
    BlinkCmpSource = { fg = c.overlay2, bg = c.none },

    ---! diffview.nvim
    DiffviewFilePanelDeletions = { fg = c.red, bold = true },
    DiffviewFilePanelFileName = { fg = c.text, bold = true },
    DiffviewFilePanelInsertions = { fg = c.green, bold = true },
    DiffviewStatusModified = { fg = c.yellow, bold = true },

    ---! flash.nvim
    FlashBackdrop = { fg = c.overlay0 },
    FlashCurrent = { fg = c.base, bg = c.peach, bold = true },
    FlashLabel = { fg = c.base, bg = c.pink, bold = true },
    FlashMatch = { fg = c.base, bg = c.sky, bold = true },
    FlashPrompt = { fg = c.text, bg = mix(t and c.none or c.surface0, c.mantle, 45) },
    FlashPromptIcon = { fg = c.peach, bg = c.none },
    FlashCursor = { fg = c.base, bg = c.text },

    ---! gitsigns.nvim
    GitSignsAdd = { fg = c.green },
    GitSignsAddNr = { link = "GitSignsAdd" },
    GitSignsChange = { fg = c.yellow },
    GitSignsChangeNr = { link = "GitSignsChange" },
    GitSignsDelete = { fg = c.red },
    GitSignsDeleteNr = { link = "GitSignsDelete" },
    GitSignsTopdelete = { fg = c.red },
    GitSignsTopdeleteNr = { link = "GitSignsTopdelete" },
    GitSignsUntracked = { fg = c.overlay1 },
    GitSignsUntrackedNr = { link = "GitSignsUntracked" },
    GitSignsCurrentLineBlame = { fg = c.overlay1, italic = true },
    GitSignsStagedAdd = { fg = staged_color(c.green) },
    GitSignsStagedAddNr = { link = "GitSignsStagedAdd" },
    GitSignsStagedChange = { fg = staged_color(c.yellow) },
    GitSignsStagedChangeNr = { link = "GitSignsStagedChange" },
    GitSignsStagedDelete = { fg = staged_color(c.red) },
    GitSignsStagedDeleteNr = { link = "GitSignsStagedDelete" },
    GitSignsStagedTopdelete = { fg = staged_color(c.red) },
    GitSignsStagedTopdeleteNr = { link = "GitSignsStagedTopdelete" },
    GitSignsStagedUntracked = { fg = staged_color(c.overlay1) },
    GitSignsStagedUntrackedNr = { link = "GitSignsStagedUntracked" },

    ---! lazy.nvim
    LazyButton = { fg = c.text, bg = c.none },
    LazyButtonActive = { fg = u.pink, bg = c.none },
    LazyCommit = { fg = c.green },
    LazyCommitIssue = { fg = c.yellow },
    LazyDir = { fg = c.blue },
    LazyH1 = { fg = lazy_badge_fg, bg = lazy_badge_bg, bold = true },
    LazyH2 = { fg = c.text, bold = true, underline = true },
    LazyNoCond = { fg = c.red },
    LazyNormal = { fg = c.text, bg = lazy_panel_bg, blend = t and 0 or 40 },
    LazyProgressDone = { fg = c.blue, bold = true },
    LazyProgressTodo = { fg = c.overlay1, italic = true },
    LazyReasonCmd = { fg = c.yellow },
    LazyReasonEvent = { fg = c.sky },
    LazyReasonFt = { fg = c.lavender },
    LazyReasonImport = { fg = c.subtext0 },
    LazyReasonKeys = { fg = c.blue },
    LazyReasonPlugin = { fg = c.red },
    LazyReasonRuntime = { fg = c.mauve },
    LazyReasonSource = { fg = c.green },
    LazyReasonStart = { fg = c.text },
    LazyOperator = { fg = c.text },
    LazyProp = { fg = c.lavender, bold = true },
    LazySpecial = { fg = c.blue },
    LazyTaskOutput = { fg = c.text },
    LazyUrl = { fg = c.blue, underline = true },
    LazyValue = { fg = c.teal },

    ---! mason.nvim
    MasonHeader = { fg = u.pink, bg = c.none },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = lazy_badge_fg, bg = lazy_badge_bg, bold = true },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = u.fg1 },
    MasonMutedBlock = { fg = u.fg1 },
    MasonNormal = { fg = c.text, bg = lazy_panel_bg, blend = t and 0 or 40 },

    ---! mini.icons
    MiniIconsAzure = { fg = c.sky },
    MiniIconsBlue = { fg = c.blue },
    MiniIconsCyan = { fg = c.sky },
    MiniIconsGreen = { fg = c.green },
    MiniIconsGrey = { fg = c.overlay2 },
    MiniIconsOrange = { fg = c.peach },
    MiniIconsPurple = { fg = c.mauve },
    MiniIconsRed = { fg = c.red },
    MiniIconsYellow = { fg = c.yellow },

    ---! mini.indentscope
    MiniIndentscopeSymbol = { fg = c.pink },
    MiniIndentscopeSymbolOff = { fg = c.red },

    ---! neo-tree.nvim
    NeoTreeCursorLine = { link = "CursorLine" },
    NeoTreeCursorLineNr = { link = "CursorLineNr" },
    NeoTreeDirectoryIcon = { fg = c.blue },
    NeoTreeDirectoryName = { fg = c.blue },
    NeoTreeExpander = { fg = c.overlay1 },
    NeoTreeFileName = { fg = c.text },
    NeoTreeFloatTitle = { link = "FloatTitle" },
    NeoTreeGitIgnored = { fg = c.overlay1 },
    NeoTreeGitModified = { fg = c.yellow },
    NeoTreeGitUntracked = { fg = c.mauve },
    NeoTreeIndentMarker = { fg = indent_marker_fg },
    NeoTreeNormal = { link = "Normal" },
    NeoTreeNormalNC = { link = "NormalNC" },
    NeoTreeRootName = { fg = c.lavender, bold = true },
    NeoTreeSignColumn = { link = "SignColumn" },
    NeoTreeFloatBorder = { link = "FloatBorder" },
    NeoTreeTab = { fg = c.overlay1, bg = c.none, bold = true },
    NeoTreeTabActive = { fg = t and c.none or c.base, bg = c.blue, bold = true },
    NeoTreeTabSeparator = { fg = c.none, bg = c.none },
    NeoTreeTabSeparatorActive = { fg = c.blue, bg = c.none },
    NeoTreeStatusLine = { link = "StatusLine" },
    NeoTreeStatusLineNC = { link = "StatusLineNC" },
    NeoTreeVertSplit = { link = "VertSplit" },
    NeoTreeEndOfBuffer = { link = "EndOfBuffer" },
    NeoTreeWinSeparator = { link = "WinSeparator" },
    NeoTreeWinbar = { fg = c.overlay1 },
    NeoTreeHiddenByName = { fg = c.overlay0 },
    NeoTreeMessage = { fg = c.subtext0 },
    NeoTreeTitleBar = { fg = t and c.none or c.base, bg = c.blue },

    ---! nvim-dap
    DapBreakpoint = { fg = c.red },
    DapBreakpointCondition = { fg = c.yellow },
    DapBreakpointRejected = { fg = c.overlay1 },
    DapLogPoint = { fg = c.blue },
    DapStopped = { fg = c.peach },
    DapStoppedLine = { bg = mix(t and c.none or c.surface0, c.peach, 25), blend = 40 },

    ---! nvim-dap-ui
    DapUIBreakpointsCurrentLine = { fg = c.green, bold = true },
    DapUIBreakpointsDisabledLine = { fg = c.overlay1 },
    DapUIBreakpointsInfo = { fg = c.green },
    DapUIBreakpointsLine = { fg = c.blue },
    DapUIBreakpointsPath = { fg = c.blue, bold = true },
    DapUICurrentFrameName = { fg = c.green, bold = true },
    DapUIDecoration = { fg = c.blue },
    DapUIFloatBorder = { fg = c.overlay1, bg = t and c.none or c.mantle },
    DapUILineNumber = { fg = c.blue },
    DapUIModifiedValue = { fg = c.peach },
    DapUIPlayPause = { fg = c.green },
    DapUIRestart = { fg = c.blue },
    DapUIScope = { fg = c.blue },
    DapUISource = { fg = c.lavender },
    DapUIStepBack = { fg = c.yellow },
    DapUIStepInto = { fg = c.blue },
    DapUIStepOut = { fg = c.blue },
    DapUIStepOver = { fg = c.blue },
    DapUIStop = { fg = c.red },
    DapUIStopNC = { fg = c.red },
    DapUIThread = { fg = c.green },
    DapUIEndofBuffer = { link = "EndOfBuffer" },
    DapUIFloatNormal = { link = "NormalFloat" },
    DapUIFrameName = { link = "Normal" },
    DapUINormal = { link = "Normal" },
    DapUIPlayPauseNC = { fg = c.green },
    DapUIRestartNC = { fg = c.green },
    DapUIStepBackNC = { fg = c.blue },
    DapUIStepIntoNC = { fg = c.blue },
    DapUIStepOutNC = { fg = c.blue },
    DapUIStepOverNC = { fg = c.blue },
    DapUIStoppedThread = { fg = c.teal },
    DapUIType = { fg = c.mauve },
    DapUIUnavailable = { fg = c.overlay2 },
    DapUIUnavailableNC = { fg = c.overlay2 },
    DapUIValue = { fg = c.teal },
    DapUIVariable = { fg = c.text },
    DapUIWatchesEmpty = { fg = c.red },
    DapUIWatchesError = { fg = c.red },
    DapUIWatchesValue = { fg = c.green },
    DapUIWinSelect = { fg = c.teal, bold = true },

    ---! nvim-dap-virtual-text
    NvimDapVirtualText = {
      fg = c.overlay1,
      bg = dap_virtual_bg,
      italic = true,
    },
    NvimDapVirtualTextChanged = {
      fg = c.text,
      bg = dap_virtual_bg,
      italic = true,
    },

    ---! snacks.nvim
    SnacksPickerLabel = { fg = c.blue, bold = true },
    SnacksPickerFile = { fg = c.teal },

    ---! notify.nvim
    NotifyERRORIcon = { fg = c.red },
    NotifyWARNIcon = { fg = c.yellow },
    NotifyINFOIcon = { fg = c.green },
    NotifyDEBUGIcon = { fg = c.peach },
    NotifyTRACEIcon = { fg = c.overlay2 },
    NotifyERRORTitle = { link = "NotifyERRORIcon" },
    NotifyWARNTitle = { link = "NotifyWARNIcon" },
    NotifyINFOTitle = { link = "NotifyINFOIcon" },
    NotifyDEBUGTitle = { link = "NotifyDEBUGIcon" },
    NotifyTRACETitle = { link = "NotifyTRACEIcon" },

    ---! treesitter-context
    TreesitterContext = { fg = c.text, bg = treesitter_context_bg },
    TreesitterContextBottom = { underline = true, sp = c.blue },
    TreesitterContextLineNumber = { fg = c.peach, bg = treesitter_context_bg },
    TreesitterContextLineNumberBottom = { underline = true, sp = c.blue },

    ---! which-key.nvim
    WhichKey = { fg = c.blue, bold = true },
    WhichKeyDesc = { fg = c.subtext0 },
    WhichKeyGroup = { fg = c.mauve, italic = true },
    WhichKeyIconAzure = { fg = c.sky },
    WhichKeyIconBlue = { fg = c.blue },
    WhichKeyIconCyan = { fg = c.sky },
    WhichKeyIconGreen = { fg = c.green },
    WhichKeyIconGrey = { fg = c.overlay2 },
    WhichKeyIconOrange = { fg = c.peach },
    WhichKeyIconPurple = { fg = c.mauve },
    WhichKeyIconRed = { fg = c.red },
    WhichKeyIconYellow = { fg = c.yellow },
    WhichKeyNormal = { fg = c.text, bg = mix(t and c.none or c.surface0, c.surface1, 65) },
    WhichKeySeparator = { fg = c.overlay1 },
    WhichKeyValue = { fg = c.green },
  }
end

return M
