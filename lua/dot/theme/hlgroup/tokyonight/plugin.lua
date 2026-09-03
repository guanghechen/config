---@class dot.theme.hlgroup.tokyonight.plugin
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.tokyonight ---@type stl.t.theme.ITokyonightPalette
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local treesitter_context_bg = t and c.none or c.bg_highlight ---@type string
  local badge_fg = u.bg1 ---@type string
  local badge_bg = u.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  local hlgroup_map = {
    ---! flash.nvim
    FlashBackdrop = { fg = c.dark3 },
    FlashCurrent = { fg = c.orange, bg = c.none, italic = true },
    FlashLabel = { bg = c.magenta2, bold = true, fg = c.fg },
    FlashMatch = { fg = c.blue1, bg = c.none, italic = true },
    FlashPrompt = { fg = c.yellow, bg = c.bg_highlight },
    FlashPromptIcon = { fg = c.orange, bg = c.none },

    ---! mason.nvim
    MasonHeader = { fg = u.pink, bg = c.none },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = badge_fg, bg = badge_bg, bold = true },
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
    MiniIndentscopeSymbol = { fg = c.magenta2 },
    MiniIndentscopeSymbolOff = { fg = c.red },

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

    ---! snacks.nvim
    SnacksPickerLabel = { fg = c.blue, bold = true },
    SnacksPickerFile = { fg = c.cyan },
  }

  return hlgroup_map
end

return M
