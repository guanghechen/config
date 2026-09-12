---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.basic.kanagawa" ---@type string

local unified = require("dot.theme.hlgroup.basic.unified")

---@class dot.theme.hlgroup.basic.kanagawa
local M = {}

M.gen_modes_color_map = unified.gen_modes_color_map

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local hlgroup_map = unified.gen_hlgroup_map(context)
  local cs = stl.color
  local c = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local bg = context.transparency and c.none or c.bg0 ---@type string

  -- Pair neutral selections and tinted inline diffs with the body foreground.
  hlgroup_map.DiffWordLeft = { fg = c.fg1, bg = c.diffDelInline or cs.mix(bg, c.brightRed, 60) }
  hlgroup_map.DiffWordRight = { fg = c.fg1, bg = c.diffAddInline or cs.mix(bg, c.brightGreen, 60) }
  hlgroup_map.PmenuSel = { fg = c.fg1, bg = c.bg3, bold = true, italic = true }
  hlgroup_map.MatchWord = { fg = c.fg1, bg = c.bg3 }
  hlgroup_map.Visual = { fg = c.fg1, bg = c.bg3, blend = 0, reverse = false }
  hlgroup_map.ComplHint = { fg = c.fg3, italic = true }
  hlgroup_map.ComplHintMore = { fg = c.fg4, italic = true }
  hlgroup_map.LspCodeLens = { fg = c.fg3, bg = c.none, italic = true }
  hlgroup_map.LineNr = { fg = c.fg4 }
  return hlgroup_map
end

return M
