---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.plugin.rosepine" ---@type string

---@class dot.theme.hlgroup.plugin.rosepine
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.rosepine ---@type stl.t.theme.IRosepinePalette
  local panel_bg = t and c.none or c.surface
  local treesitter_context_bg = t and c.none or c.highlightLow
  local badge_fg = c.surface ---@type string
  local badge_bg = c.rose ---@type string
  -- Pine-family icons need foam's contrast on dark backgrounds.
  local pine_icon_fg = context.scheme.darken and c.foam or c.pine ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  return {
    ---! completion
    CmpDoc = { fg = c.text, bg = panel_bg },
    CmpDocBorder = { fg = c.muted, bg = panel_bg },
    CmpDocSeparator = { fg = c.muted, bg = panel_bg },
    CmpKindClass = { fg = c.foam, bg = c.none },
    CmpKindColor = { fg = c.iris, bg = c.none },
    CmpKindConstant = { fg = c.gold, bg = c.none },
    CmpKindConstructor = { fg = c.rose, bg = c.none },
    CmpKindEnum = { fg = c.foam, bg = c.none },
    CmpKindEnumMember = { fg = c.gold, bg = c.none },
    CmpKindEvent = { fg = c.foam, bg = c.none },
    CmpKindField = { fg = c.foam, bg = c.none },
    CmpKindFile = { fg = c.rose, bg = c.none },
    CmpKindFolder = { fg = c.rose, bg = c.none },
    CmpKindFunction = { fg = c.rose, bg = c.none },
    CmpKindInterface = { fg = c.foam, bg = c.none },
    CmpKindKeyword = { fg = c.pine, bg = c.none },
    CmpKindMethod = { fg = c.rose, bg = c.none },
    CmpKindModule = { fg = c.rose, bg = c.none },
    CmpKindOperator = { fg = c.subtle, bg = c.none },
    CmpKindProperty = { fg = c.foam, bg = c.none },
    CmpKindReference = { fg = c.love, bg = c.none },
    CmpKindSnippet = { fg = c.iris, bg = c.none },
    CmpKindStruct = { fg = c.foam, bg = c.none },
    CmpKindText = { fg = c.gold, bg = c.none },
    CmpKindTypeParameter = { fg = c.foam, bg = c.none },
    CmpKindUnit = { fg = c.pine, bg = c.none },
    CmpKindValue = { fg = c.gold, bg = c.none },
    CmpKindVariable = { fg = c.text, bg = c.none },
    CmpLabelDeprecated = { strikethrough = true },
    CmpSignatureHelp = { fg = c.text, bg = panel_bg },
    CmpSignatureHelpActiveParameter = { link = "LspSignatureActiveParameter" },
    CmpSignatureHelpBorder = { fg = c.muted, bg = panel_bg },

    ---! flash.nvim
    FlashBackdrop = { fg = c.muted },
    FlashCurrent = { fg = c.base, bg = c.gold, bold = true },
    FlashLabel = { fg = c.base, bg = c.iris, bold = true },
    FlashMatch = { fg = c.base, bg = c.foam, bold = true },
    FlashPrompt = { fg = c.text, bg = panel_bg },
    FlashPromptIcon = { fg = c.gold, bg = c.none },
    FlashCursor = { fg = c.base, bg = c.text },

    ---! mason.nvim
    MasonHeader = { fg = c.rose, bg = c.none },
    MasonHighlight = { fg = c.rose },
    MasonHighlightBlock = { fg = badge_fg, bg = badge_bg, bold = true },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = c.text },
    MasonMutedBlock = { fg = c.text },
    MasonNormal = { fg = c.text, bg = panel_bg },

    ---! mini.icons
    MiniIconsAzure = { fg = c.foam },
    MiniIconsBlue = { fg = pine_icon_fg },
    MiniIconsCyan = { fg = c.foam },
    MiniIconsGreen = { fg = pine_icon_fg },
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
