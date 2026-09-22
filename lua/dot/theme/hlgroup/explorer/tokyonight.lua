---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.explorer.tokyonight" ---@type string

local unified = require("dot.theme.hlgroup.explorer.unified")

---@class dot.theme.hlgroup.explorer.tokyonight
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local hlgroup_map = unified.gen_hlgroup_map(context)
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette

  hlgroup_map.m_ft_git_ignored_cl = { fg = u.fg1, bg = u.bg3, bold = true }
  hlgroup_map.m_ft_git_ignored_clb = { fg = u.fg1, bg = u.bg2, bold = true }
  hlgroup_map.m_ft_git_other_cl = { fg = u.fg1, bg = u.bg3, bold = true }
  hlgroup_map.m_ft_git_other_clb = { fg = u.fg1, bg = u.bg2, bold = true }
  hlgroup_map.m_ft_git_untracked_cl = { fg = u.fg1, bg = u.bg3, bold = true }
  hlgroup_map.m_ft_git_untracked_clb = { fg = u.fg1, bg = u.bg2, bold = true }
  hlgroup_map.m_ft_position = { fg = u.fg3 }
  return hlgroup_map
end

return M
