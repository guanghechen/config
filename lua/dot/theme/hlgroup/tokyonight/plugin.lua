---@class dot.theme.hlgroup.tokyonight.plugin
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local t = context.transparency ---@type boolean
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local treesitter_context_bg = t and u.none or u.bg2 ---@type string
  local badge_fg = u.bg0 ---@type string
  local badge_bg = u.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  local hlgroup_map = {
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
