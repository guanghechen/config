---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.plugin.rosepine" ---@type string

---@class dot.theme.hlgroup.plugin.rosepine
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.rosepine ---@type stl.t.theme.IRosepinePalette
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local panel_bg = t and c.none or c.surface
  local treesitter_context_bg = t and c.none or c.highlightLow
  local badge_fg = u.bg1 ---@type string
  local badge_bg = u.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  return {
    ---! blink.cmp
    BlinkCmpDoc = { fg = c.text, bg = panel_bg },
    BlinkCmpDocBorder = { fg = c.muted, bg = panel_bg },
    BlinkCmpDocSeparator = { fg = c.muted, bg = panel_bg },
    BlinkCmpGhostText = { fg = c.muted, default = true },
    BlinkCmpItemIdx = { fg = c.subtle, bg = c.none },
    BlinkCmpKindClass = { fg = c.foam, bg = c.none },
    BlinkCmpKindCodeium = { fg = c.foam, bg = c.none },
    BlinkCmpKindColor = { fg = c.iris, bg = c.none },
    BlinkCmpKindConstant = { fg = c.gold, bg = c.none },
    BlinkCmpKindConstructor = { fg = c.rose, bg = c.none },
    BlinkCmpKindDefault = { fg = c.subtle, bg = c.none },
    BlinkCmpKindEnum = { fg = c.foam, bg = c.none },
    BlinkCmpKindEnumMember = { fg = c.gold, bg = c.none },
    BlinkCmpKindEvent = { fg = c.foam, bg = c.none },
    BlinkCmpKindField = { fg = c.foam, bg = c.none },
    BlinkCmpKindFile = { fg = c.rose, bg = c.none },
    BlinkCmpKindFolder = { fg = c.rose, bg = c.none },
    BlinkCmpKindFunction = { fg = c.rose, bg = c.none },
    BlinkCmpKindIdentifier = { fg = c.text, bg = c.none },
    BlinkCmpKindInterface = { fg = c.foam, bg = c.none },
    BlinkCmpKindKeyword = { fg = c.pine, bg = c.none },
    BlinkCmpKindMethod = { fg = c.rose, bg = c.none },
    BlinkCmpKindModule = { fg = c.rose, bg = c.none },
    BlinkCmpKindOperator = { fg = c.subtle, bg = c.none },
    BlinkCmpKindProperty = { fg = c.foam, bg = c.none },
    BlinkCmpKindReference = { fg = c.love, bg = c.none },
    BlinkCmpKindSnippet = { fg = c.iris, bg = c.none },
    BlinkCmpKindStruct = { fg = c.foam, bg = c.none },
    BlinkCmpKindStructure = { fg = c.foam, bg = c.none },
    BlinkCmpKindSupermaven = { fg = c.foam, bg = c.none },
    BlinkCmpKindTabNine = { fg = c.foam, bg = c.none },
    BlinkCmpKindText = { fg = c.gold, bg = c.none },
    BlinkCmpKindType = { fg = c.foam, bg = c.none },
    BlinkCmpKindTypeParameter = { fg = c.foam, bg = c.none },
    BlinkCmpKindUnit = { fg = c.pine, bg = c.none },
    BlinkCmpKindValue = { fg = c.gold, bg = c.none },
    BlinkCmpKindVariable = { fg = c.text, bg = c.none },
    BlinkCmpLabel = { fg = c.text, bg = c.none },
    BlinkCmpLabelDeprecated = { fg = c.muted, bg = c.none, strikethrough = true },
    BlinkCmpLabelMatch = { fg = c.rose, bg = c.none, bold = true },
    BlinkCmpMenu = { fg = c.text, bg = panel_bg },
    BlinkCmpMenuBorder = { fg = c.muted, bg = panel_bg },
    BlinkCmpMenuSelection = { fg = c.text, bg = c.highlightMed },
    BlinkCmpScrollBarGutter = { bg = panel_bg },
    BlinkCmpScrollBarThumb = { bg = c.highlightMed },
    BlinkCmpSignatureHelp = { fg = c.text, bg = panel_bg },
    BlinkCmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    BlinkCmpSignatureHelpBorder = { fg = c.muted, bg = panel_bg },
    BlinkCmpSource = { fg = c.subtle, bg = c.none },

    ---! flash.nvim
    FlashBackdrop = { fg = c.muted },
    FlashCurrent = { fg = c.base, bg = c.gold, bold = true },
    FlashLabel = { fg = c.base, bg = c.iris, bold = true },
    FlashMatch = { fg = c.base, bg = c.foam, bold = true },
    FlashPrompt = { fg = c.text, bg = panel_bg },
    FlashPromptIcon = { fg = c.gold, bg = c.none },
    FlashCursor = { fg = c.base, bg = c.text },

    ---! mason.nvim
    MasonHeader = { fg = u.pink, bg = c.none },
    MasonHighlight = { fg = c.rose },
    MasonHighlightBlock = { fg = badge_fg, bg = badge_bg, bold = true },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = u.fg1 },
    MasonMutedBlock = { fg = u.fg1 },
    MasonNormal = { fg = c.text, bg = panel_bg },

    ---! mini.icons
    MiniIconsAzure = { fg = c.foam },
    MiniIconsBlue = { fg = c.pine },
    MiniIconsCyan = { fg = c.foam },
    MiniIconsGreen = { fg = c.pine },
    MiniIconsGrey = { fg = c.subtle },
    MiniIconsOrange = { fg = c.gold },
    MiniIconsPurple = { fg = c.iris },
    MiniIconsRed = { fg = c.love },
    MiniIconsYellow = { fg = c.gold },

    ---! snacks.nvim
    SnacksPickerLabel = { fg = c.rose, bold = true },
    SnacksPickerFile = { fg = c.foam },

    ---! notify.nvim
    NotifyERRORIcon = { fg = c.love },
    NotifyWARNIcon = { fg = c.gold },
    NotifyINFOIcon = { fg = c.pine },
    NotifyDEBUGIcon = { fg = c.gold },
    NotifyTRACEIcon = { fg = c.subtle },
    NotifyERRORTitle = { link = "NotifyERRORIcon" },
    NotifyWARNTitle = { link = "NotifyWARNIcon" },
    NotifyINFOTitle = { link = "NotifyINFOIcon" },
    NotifyDEBUGTitle = { link = "NotifyDEBUGIcon" },
    NotifyTRACETitle = { link = "NotifyTRACEIcon" },

    ---! treesitter-context
    TreesitterContext = { fg = c.text, bg = treesitter_context_bg },
    TreesitterContextBottom = { underline = true, sp = c.rose },
    TreesitterContextLineNumber = { fg = c.gold, bg = treesitter_context_bg },
    TreesitterContextLineNumberBottom = { underline = true, sp = c.rose },
  }
end

return M
