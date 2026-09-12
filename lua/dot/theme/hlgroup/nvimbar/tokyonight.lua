---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.nvimbar.tokyonight" ---@type string

local unified = require("dot.theme.hlgroup.nvimbar.unified")

---@class dot.theme.hlgroup.nvimbar.tokyonight
local M = {}

---@param context                       stl.t.theme.IContext
---@return dot.theme.hlgroup.nvimbar.IHlgroupMap
function M.gen_hlgroup_map(context)
  local hlgroup_map = unified.gen_hlgroup_map(context)
  local c = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette

  -- Tokyo Night's bg4 needs a stronger foreground for terminal controls.
  for _, position in ipairs({ "f_sl", "f_tl", "f_wl" }) do
    hlgroup_map[position .. "_term_button"] = { fg = c.fg1, bg = c.bg4 }
    hlgroup_map[position .. "_term_index"] = { fg = c.fg1, bg = c.bg4 }
  end
  return hlgroup_map
end

return M
