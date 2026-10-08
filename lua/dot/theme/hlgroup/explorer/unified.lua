---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.explorer.unified" ---@type string

---@class dot.theme.hlgroup.explorer.unified
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local t = context.transparency ---@type boolean
  local bg = t and u.none or u.bg0 ---@type string

  local hlgroup_map = {
    ---explorer
    m_ex_bg = { fg = u.fg1, bg = bg },
    m_ex_border = { fg = u.bg3, bg = bg },
    m_ex_cursorline = { bg = u.bg3 },
    m_ex_cursorline_blur = { bg = u.bg2 },
    m_ex_eob = { fg = bg, bg = bg },
    m_ex_ignored = { fg = u.fg4 },
    m_ex_indent = { fg = u.bg3 },
    m_ex_indent_active = { fg = u.fg4 },
    m_ex_symlink = { fg = u.brightPurple, bold = true },
    m_ex_winbar = { fg = u.fg2, bg = u.bg1, bold = true },

    ---explorer (file explorer)
    m_fe_date = { fg = u.fg4 },
    m_fe_group = { fg = u.red },
    m_fe_name_dir = { fg = u.blue },
    m_fe_name_file = { fg = u.fg1 },
    m_fe_owner = { fg = u.red },
    m_fe_perm = { fg = u.fg1 },
    m_fe_perm_dir = { fg = u.blue },
    m_fe_perm_file = { fg = u.fg1 },
    m_fe_size = { fg = u.green },

    ---explorer (filetree)
    m_ft_dirname = { fg = u.brightBlue },
    m_ft_filename = { fg = u.fg2 },
    m_ft_git_add = { fg = u.brightGreen, bold = true },
    m_ft_git_change = { fg = u.brightYellow, bold = true },
    m_ft_git_delete = { fg = u.brightRed, bold = true },
    m_ft_git_ignored = { fg = u.fg4, bold = true },
    m_ft_git_other = { fg = u.fg3, bold = true },
    m_ft_git_rename = { fg = u.brightBlue, bold = true },
    m_ft_git_staged = { fg = u.brightGreen, bold = true },
    m_ft_git_unmerged = { fg = u.brightOrange, bold = true },
    m_ft_git_unstaged = { fg = u.brightYellow, bold = true },
    m_ft_git_untracked = { fg = u.fg4, bold = true },
    m_ft_pathsep = { fg = u.fg4 },
    m_ft_position = { fg = u.bg4 },
    m_ft_reference = { fg = u.purple, bold = true, italic = true },
    m_ft_text = { fg = u.fg4 },
  }

  local link_color = hlgroup_map.m_ex_symlink.fg ---@type string
  for _, status in ipairs({
    "add",
    "change",
    "delete",
    "ignored",
    "other",
    "rename",
    "staged",
    "unmerged",
    "unstaged",
    "untracked",
  }) do
    hlgroup_map["m_ex_symlink_" .. status] = {
      fg = stl.color.mix(link_color, hlgroup_map["m_ft_git_" .. status].fg, 60),
      bold = true,
    }
  end
  return hlgroup_map
end

return M
