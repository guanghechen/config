---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.plugin.tokyonight" ---@type string

---@class dot.theme.hlgroup.plugin.tokyonight
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local t = context.transparency ---@type boolean
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local item_kind_bg = u.none ---@type string
  local cmp_panel_bg = t and u.none or cs.mix(u.bg1, u.bg0, 80) ---@type string
  local treesitter_context_bg = t and u.none or u.bg2 ---@type string
  local badge_fg = u.bg0 ---@type string
  local badge_bg = u.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  local hlgroup_map = {
    ---! completion
    CmpDoc = { fg = u.fg1, bg = cmp_panel_bg },
    CmpDocBorder = { fg = u.blue, bg = cmp_panel_bg },
    CmpDocSeparator = { fg = u.fg4, bg = cmp_panel_bg },
    CmpKindClass = { fg = u.orange, bg = item_kind_bg },
    CmpKindColor = { fg = u.fg1, bg = item_kind_bg },
    CmpKindConstant = { fg = u.orange, bg = item_kind_bg },
    CmpKindConstructor = { fg = u.purple, bg = item_kind_bg },
    CmpKindEnum = { fg = u.orange, bg = item_kind_bg },
    CmpKindEnumMember = { fg = u.brightAqua, bg = item_kind_bg },
    CmpKindEvent = { fg = u.orange, bg = item_kind_bg },
    CmpKindField = { fg = u.brightGreen, bg = item_kind_bg },
    CmpKindFile = { fg = u.fg1, bg = item_kind_bg },
    CmpKindFolder = { fg = u.blue, bg = item_kind_bg },
    CmpKindFunction = { fg = u.blue, bg = item_kind_bg },
    CmpKindInterface = { fg = u.brightBlue, bg = item_kind_bg },
    CmpKindKeyword = { fg = u.aqua, bg = item_kind_bg },
    CmpKindMethod = { fg = u.blue, bg = item_kind_bg },
    CmpKindModule = { fg = u.yellow, bg = item_kind_bg },
    CmpKindOperator = { fg = u.aqua, bg = item_kind_bg },
    CmpKindProperty = { fg = u.brightGreen, bg = item_kind_bg },
    CmpKindReference = { fg = u.brightAqua, bg = item_kind_bg },
    CmpKindSnippet = { fg = u.fg3, bg = item_kind_bg },
    CmpKindStruct = { fg = u.orange, bg = item_kind_bg },
    CmpKindText = { fg = u.green, bg = item_kind_bg },
    CmpKindTypeParameter = { fg = u.brightAqua, bg = item_kind_bg },
    CmpKindUnit = { fg = u.orange, bg = item_kind_bg },
    CmpKindValue = { fg = u.green, bg = item_kind_bg },
    CmpKindVariable = { fg = u.fg1, bg = item_kind_bg },
    CmpLabelDeprecated = { strikethrough = true },
    CmpSignatureHelp = { fg = u.fg1, bg = cmp_panel_bg },
    CmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    CmpSignatureHelpBorder = { fg = u.blue, bg = cmp_panel_bg },

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
