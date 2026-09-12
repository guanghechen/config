---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.widget.catppuccin" ---@type string

local unified = require("dot.theme.hlgroup.widget.unified")

---@class dot.theme.hlgroup.widget.catppuccin
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local hlgroup_map = unified.gen_hlgroup_map(context)
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette

  -- Keep tinted surfaces readable with this theme's foreground.
  hlgroup_map.f_diff_word_left = { fg = u.fg1, bg = u.diffDelInline }
  hlgroup_map.f_diff_word_right = { fg = u.fg1, bg = u.diffAddInline }
  return hlgroup_map
end

return M
