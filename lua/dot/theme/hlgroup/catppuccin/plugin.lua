---@class dot.theme.hlgroup.catppuccin.plugin
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local t = context.transparency ---@type boolean
  local c = context.scheme.palette.catppuccin ---@type stl.t.theme.ICatppuccinPalette
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local panel_bg = cs.mix(t and c.none or c.mantle, c.surface1, 60)
  local treesitter_context_bg = t and c.none or c.surface0
  local badge_fg = u.bg1 ---@type string
  local badge_bg = u.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  return {
    ---! flash.nvim
    FlashBackdrop = { fg = c.overlay0 },
    FlashCurrent = { fg = c.base, bg = c.peach, bold = true },
    FlashLabel = { fg = c.base, bg = c.pink, bold = true },
    FlashMatch = { fg = c.base, bg = c.sky, bold = true },
    FlashPrompt = { fg = c.text, bg = cs.mix(t and c.none or c.surface0, c.mantle, 45) },
    FlashPromptIcon = { fg = c.peach, bg = c.none },
    FlashCursor = { fg = c.base, bg = c.text },

    ---! mason.nvim
    MasonHeader = { fg = u.pink, bg = c.none },
    MasonHighlight = { fg = c.blue },
    MasonHighlightBlock = { fg = badge_fg, bg = badge_bg, bold = true },
    MasonHighlightBlockBold = { link = "MasonHighlightBlock" },
    MasonHeaderSecondary = { link = "MasonHighlightBlock" },
    MasonMuted = { fg = u.fg1 },
    MasonMutedBlock = { fg = u.fg1 },
    MasonNormal = { fg = c.text, bg = panel_bg, blend = t and 0 or 40 },

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
  }
end

return M
