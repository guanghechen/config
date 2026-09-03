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

  local treesitter_context_bg = t and c.none or c.bg2 ---@type string
  local badge_fg = c.bg1 ---@type string
  local badge_bg = c.pink ---@type string

  ---@type table<string, stl.t.theme.IHlgroup>
  return {
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

    ---! mini.indentscope
    MiniIndentscopeSymbol = { fg = c.pink },
    MiniIndentscopeSymbolOff = { fg = c.red },

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
