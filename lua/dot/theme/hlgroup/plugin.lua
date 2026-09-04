---@class dot.theme.hlgroup.plugin
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local md = string.format("dot.theme.hlgroup.%s.plugin", context.scheme.theme) ---@type string
  local ok, mod = pcall(require, md)
  if ok and mod then
    return mod.gen_hlgroup_map(context)
  end

  return M.default_gen_hlgroup_map(context)
end

function M.default_gen_hlgroup_map(context)
  local cs = stl.color
  local c = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local t = context.transparency ---@type boolean

  local item_kind_bg = c.none ---@type string
  local cmp_panel_bg = cs.mix(c.bg0, c.bg2, 75) ---@type string
  local treesitter_context_bg = t and c.none or c.bg2 ---@type string
  local badge_fg = c.bg1 ---@type string
  local badge_bg = c.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
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
    BlinkCmpMenuSelection = { fg = c.fg0, bg = c.bg4 },
    BlinkCmpScrollBarGutter = { bg = cmp_panel_bg },
    BlinkCmpScrollBarThumb = { bg = c.bg4 },
    BlinkCmpSignatureHelp = { bg = cmp_panel_bg },
    BlinkCmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    BlinkCmpSignatureHelpBorder = { fg = c.bg4, bg = cmp_panel_bg },
    BlinkCmpSource = { fg = c.fg3, bg = item_kind_bg },

    ---! flash.nvim
    FlashBackdrop = { fg = c.bg4, bg = c.none },
    FlashCurrent = { fg = c.bg0, bg = c.orange, bold = true },
    FlashLabel = { fg = c.bg0, bg = c.pink, bold = true },
    FlashMatch = { fg = c.bg0, bg = c.aqua, bold = true },
    FlashPrompt = { fg = c.yellow, bg = c.bg2 },
    FlashPromptIcon = { fg = c.orange, bg = c.none },
    FlashCursor = { fg = c.bg0, bg = c.fg1 },

    ---! mason.nvim
    MasonHeader = { fg = c.pink, bg = c.none },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = badge_fg, bg = badge_bg, bold = true },
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

    ---! snacks.nvim
    SnacksPickerLabel = { fg = c.brightBlue, bold = true },
    SnacksPickerFile = { fg = c.brightAqua },
  }
end

return M
