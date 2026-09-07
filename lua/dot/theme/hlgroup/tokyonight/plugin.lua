---@class dot.theme.hlgroup.tokyonight.plugin
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local t = context.transparency ---@type boolean
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local item_kind_bg = u.none ---@type string
  local cmp_panel_bg = cs.mix(u.bg1, u.bg0, 80) ---@type string
  local treesitter_context_bg = t and u.none or u.bg2 ---@type string
  local badge_fg = u.bg0 ---@type string
  local badge_bg = u.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  local hlgroup_map = {
    ---! blink.cmp
    BlinkCmpDoc = { fg = u.fg1, bg = cmp_panel_bg },
    BlinkCmpDocBorder = { fg = u.blue, bg = cmp_panel_bg },
    BlinkCmpDocSeparator = { fg = u.fg4, bg = cmp_panel_bg },
    BlinkCmpGhostText = { link = "Comment" },
    BlinkCmpItemIdx = { fg = u.fg3, bg = item_kind_bg },
    BlinkCmpKindClass = { fg = u.orange, bg = item_kind_bg },
    BlinkCmpKindCodeium = { fg = u.brightAqua, bg = item_kind_bg },
    BlinkCmpKindColor = { fg = u.fg1, bg = item_kind_bg },
    BlinkCmpKindConstant = { fg = u.orange, bg = item_kind_bg },
    BlinkCmpKindConstructor = { fg = u.purple, bg = item_kind_bg },
    BlinkCmpKindDefault = { fg = u.fg2, bg = item_kind_bg },
    BlinkCmpKindEnum = { fg = u.orange, bg = item_kind_bg },
    BlinkCmpKindEnumMember = { fg = u.brightAqua, bg = item_kind_bg },
    BlinkCmpKindEvent = { fg = u.orange, bg = item_kind_bg },
    BlinkCmpKindField = { fg = u.brightGreen, bg = item_kind_bg },
    BlinkCmpKindFile = { fg = u.fg1, bg = item_kind_bg },
    BlinkCmpKindFolder = { fg = u.blue, bg = item_kind_bg },
    BlinkCmpKindFunction = { fg = u.blue, bg = item_kind_bg },
    BlinkCmpKindIdentifier = { fg = u.purple, bg = item_kind_bg },
    BlinkCmpKindInterface = { fg = u.brightBlue, bg = item_kind_bg },
    BlinkCmpKindKeyword = { fg = u.aqua, bg = item_kind_bg },
    BlinkCmpKindMethod = { fg = u.blue, bg = item_kind_bg },
    BlinkCmpKindModule = { fg = u.yellow, bg = item_kind_bg },
    BlinkCmpKindOperator = { fg = u.aqua, bg = item_kind_bg },
    BlinkCmpKindProperty = { fg = u.brightGreen, bg = item_kind_bg },
    BlinkCmpKindReference = { fg = u.brightAqua, bg = item_kind_bg },
    BlinkCmpKindSnippet = { fg = u.fg3, bg = item_kind_bg },
    BlinkCmpKindStruct = { fg = u.orange, bg = item_kind_bg },
    BlinkCmpKindStructure = { fg = u.orange, bg = item_kind_bg },
    BlinkCmpKindSupermaven = { fg = u.brightAqua, bg = item_kind_bg },
    BlinkCmpKindTabNine = { fg = u.brightAqua, bg = item_kind_bg },
    BlinkCmpKindText = { fg = u.green, bg = item_kind_bg },
    BlinkCmpKindType = { fg = u.brightBlue, bg = item_kind_bg },
    BlinkCmpKindTypeParameter = { fg = u.brightAqua, bg = item_kind_bg },
    BlinkCmpKindUnit = { fg = u.orange, bg = item_kind_bg },
    BlinkCmpKindValue = { fg = u.green, bg = item_kind_bg },
    BlinkCmpKindVariable = { fg = u.fg1, bg = item_kind_bg },
    BlinkCmpLabel = { fg = u.fg1, bg = item_kind_bg },
    BlinkCmpLabelDeprecated = { fg = u.fg3, bg = item_kind_bg, strikethrough = true },
    BlinkCmpLabelMatch = { fg = u.brightBlue, bg = item_kind_bg },
    BlinkCmpMenu = { fg = u.fg1, bg = cmp_panel_bg },
    BlinkCmpMenuBorder = { fg = u.blue, bg = cmp_panel_bg },
    BlinkCmpMenuSelection = { fg = u.fg1, bg = u.bg3 },
    BlinkCmpScrollBarGutter = { bg = cmp_panel_bg },
    BlinkCmpScrollBarThumb = { bg = u.bg2 },
    BlinkCmpSignatureHelp = { fg = u.fg1, bg = cmp_panel_bg },
    BlinkCmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    BlinkCmpSignatureHelpBorder = { fg = u.blue, bg = cmp_panel_bg },
    BlinkCmpSource = { fg = u.fg3, bg = item_kind_bg },

    ---! flash.nvim
    FlashBackdrop = { fg = u.fg4 },
    FlashCurrent = { fg = u.orange, bg = u.none, italic = true },
    FlashLabel = { bg = u.pink, bold = true, fg = u.bg0 },
    FlashMatch = { fg = u.brightBlue, bg = u.none, italic = true },
    FlashPrompt = { fg = u.yellow, bg = u.bg2 },
    FlashPromptIcon = { fg = u.orange, bg = u.none },

    ---! mason.nvim
    MasonHeader = { fg = u.pink, bg = u.none },
    MasonHighlight = { fg = u.blue },
    MasonHighlightBlock = { fg = badge_fg, bg = badge_bg, bold = true },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = u.fg1 },
    MasonMutedBlock = { fg = u.fg1 },
    MasonNormal = { fg = u.fg1, bg = t and u.none or cs.mix(u.bg0, u.bg1, 60), blend = 50 },

    ---! mini.icons
    MiniIconsAzure = { fg = u.brightBlue },
    MiniIconsBlue = { fg = u.blue },
    MiniIconsCyan = { fg = u.brightAqua },
    MiniIconsGreen = { fg = u.green },
    MiniIconsGrey = { fg = u.fg1 },
    MiniIconsOrange = { fg = u.orange },
    MiniIconsPurple = { fg = u.brightPurple },
    MiniIconsRed = { fg = u.red },
    MiniIconsYellow = { fg = u.yellow },

    ---! nvim-notify
    NotifyERRORIcon = { fg = u.red },
    NotifyWARNIcon = { fg = u.yellow },
    NotifyINFOIcon = { fg = u.brightBlue },
    NotifyDEBUGIcon = { fg = u.brightAqua },
    NotifyTRACEIcon = { fg = u.fg4 },

    NotifyERRORTitle = { link = "NotifyERRORIcon" },
    NotifyWARNTitle = { link = "NotifyWARNIcon" },
    NotifyINFOTitle = { link = "NotifyINFOIcon" },
    NotifyDEBUGTitle = { link = "NotifyDEBUGIcon" },
    NotifyTRACETitle = { link = "NotifyTRACEIcon" },

    ---! nvim-treesitter-context
    TreesitterContext = { fg = u.fg1, bg = treesitter_context_bg },
    TreesitterContextBottom = {},
    TreesitterContextLineNumber = { fg = u.orange, bg = treesitter_context_bg },
    TreesitterContextLineNumberBottom = { underline = true },

    ---! snacks.nvim
    SnacksPickerLabel = { fg = u.blue, bold = true },
    SnacksPickerFile = { fg = u.aqua },
  }

  return hlgroup_map
end

return M
