---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.plugin.unified" ---@type string

---@class dot.theme.hlgroup.plugin.unified
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local c = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local t = context.transparency ---@type boolean

  local item_kind_bg = c.none ---@type string
  local cmp_panel_bg = t and c.none or cs.mix(c.bg0, c.bg2, 75) ---@type string
  local treesitter_context_bg = t and c.none or c.bg2 ---@type string
  local badge_fg = c.bg1 ---@type string
  local badge_bg = c.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  return {
    ---! cmp
    CmpDoc = { bg = cmp_panel_bg },
    CmpDocBorder = { fg = c.bg4, bg = cmp_panel_bg },
    CmpDocSeparator = { fg = c.bg4, bg = cmp_panel_bg },
    CmpKindClass = { fg = c.aqua, bg = item_kind_bg },
    CmpKindColor = { fg = c.fg1, bg = item_kind_bg },
    CmpKindConstant = { fg = c.orange, bg = item_kind_bg },
    CmpKindConstructor = { fg = c.blue, bg = item_kind_bg },
    CmpKindEnum = { fg = c.blue, bg = item_kind_bg },
    CmpKindEnumMember = { fg = c.purple, bg = item_kind_bg },
    CmpKindEvent = { fg = c.yellow, bg = item_kind_bg },
    CmpKindField = { fg = c.red, bg = item_kind_bg },
    CmpKindFile = { fg = c.fg1, bg = item_kind_bg },
    CmpKindFolder = { fg = c.fg1, bg = item_kind_bg },
    CmpKindFunction = { fg = c.blue, bg = item_kind_bg },
    CmpKindInterface = { fg = c.green, bg = item_kind_bg },
    CmpKindKeyword = { fg = c.fg1, bg = item_kind_bg },
    CmpKindMethod = { fg = c.blue, bg = item_kind_bg },
    CmpKindModule = { fg = c.yellow, bg = item_kind_bg },
    CmpKindOperator = { fg = c.fg1, bg = item_kind_bg },
    CmpKindProperty = { fg = c.red, bg = item_kind_bg },
    CmpKindReference = { fg = c.fg1, bg = item_kind_bg },
    CmpKindSnippet = { fg = c.red, bg = item_kind_bg },
    CmpKindStruct = { fg = c.purple, bg = item_kind_bg },
    CmpKindText = { fg = c.green, bg = item_kind_bg },
    CmpKindTypeParameter = { fg = c.red, bg = item_kind_bg },
    CmpKindUnit = { fg = c.purple, bg = item_kind_bg },
    CmpKindValue = { fg = c.aqua, bg = item_kind_bg },
    CmpKindVariable = { fg = c.purple, bg = item_kind_bg },
    CmpLabelDeprecated = { italic = true, strikethrough = true },
    CmpSignatureHelp = { bg = cmp_panel_bg },
    CmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    CmpSignatureHelpBorder = { fg = c.bg4, bg = cmp_panel_bg },

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
    MasonNormal = { fg = c.fg1, bg = t and c.none or cs.mix(c.bg0, c.bg1, 60) },

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
