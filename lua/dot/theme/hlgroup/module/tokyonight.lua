---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.module.tokyonight" ---@type string

local unified = require("dot.theme.hlgroup.module.unified")

---@class dot.theme.hlgroup.module.tokyonight
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local hlgroup_map = unified.gen_hlgroup_map(context)
  local cs = stl.color
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local bg = context.transparency and u.none or u.bg0 ---@type string

  -- Keep tinted surfaces readable with this theme's foreground.
  hlgroup_map.m_ft_git_ignored_cl = { fg = u.fg1, bg = u.bg3, bold = true }
  hlgroup_map.m_ft_git_ignored_clb = { fg = u.fg1, bg = u.bg2, bold = true }
  hlgroup_map.m_ft_git_other_cl = { fg = u.fg1, bg = u.bg3, bold = true }
  hlgroup_map.m_ft_git_other_clb = { fg = u.fg1, bg = u.bg2, bold = true }
  hlgroup_map.m_ft_git_untracked_cl = { fg = u.fg1, bg = u.bg3, bold = true }
  hlgroup_map.m_ft_git_untracked_clb = { fg = u.fg1, bg = u.bg2, bold = true }
  hlgroup_map.m_ft_position = { fg = u.fg3 }
  hlgroup_map.m_git_buffer_blame = { fg = u.fg3, italic = true }
  hlgroup_map.m_git_sign_add_staged = { fg = cs.mix(u.bg0, u.green, 80) }
  hlgroup_map.m_git_sign_change_staged = { fg = cs.mix(u.bg0, u.blue, 80) }
  hlgroup_map.m_git_sign_delete_staged = { fg = cs.mix(u.bg0, u.red, 80) }
  hlgroup_map.m_dv_winbar_dim = { fg = u.fg2, bg = u.bg1 }
  hlgroup_map.m_dv_add_inline = { fg = u.fg1, bg = u.diffAddInline or cs.mix(bg, u.brightGreen, 60) }
  hlgroup_map.m_dv_del_inline = { fg = u.fg1, bg = u.diffDelInline or cs.mix(bg, u.brightRed, 60) }
  hlgroup_map.m_wk_icon_grey = { fg = u.fg3 }
  return hlgroup_map
end

return M
