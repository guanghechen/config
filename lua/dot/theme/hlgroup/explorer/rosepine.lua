---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.explorer.rosepine" ---@type string

---@class dot.theme.hlgroup.explorer.rosepine
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette.rosepine ---@type stl.t.theme.IRosepinePalette
  local t = context.transparency ---@type boolean
  local bg = t and c.none or c.base ---@type string

  local hlgroup_map = {
    ---explorer
    m_ex_bg = { fg = c.text, bg = bg },
    m_ex_border = { fg = c.highlightMed, bg = bg },
    m_ex_copy = { fg = c.gold, italic = true },
    m_ex_copy_cl = { fg = c.gold, bg = c.highlightMed, italic = true },
    m_ex_copy_clb = { fg = c.gold, bg = c.overlay, italic = true },
    m_ex_cursorline = { bg = c.highlightMed },
    m_ex_cursorline_blur = { bg = c.overlay },
    m_ex_cut = { fg = c.love, italic = true },
    m_ex_cut_cl = { fg = c.love, bg = c.highlightMed, italic = true },
    m_ex_cut_clb = { fg = c.love, bg = c.overlay, italic = true },
    m_ex_eob = { fg = bg, bg = bg },
    m_ex_ignored = { fg = c.muted },
    m_ex_indent = { fg = c.highlightMed },
    m_ex_indent_active = { fg = c.muted },
    m_ex_selected = { fg = c.gold, bold = true },
    m_ex_selected_cl = { fg = c.gold, bg = c.highlightMed, bold = true },
    m_ex_selected_clb = { fg = c.gold, bg = c.overlay, bold = true },
    m_ex_symlink = { fg = c.iris, bold = true },
    m_ex_winbar = { fg = c.subtle, bg = c.surface, bold = true },

    ---explorer (file explorer)
    m_fe_date = { fg = c.muted },
    m_fe_group = { fg = c.love },
    m_fe_name_dir = { fg = c.rose },
    m_fe_name_file = { fg = c.text },
    m_fe_owner = { fg = c.love },
    m_fe_perm = { fg = c.text },
    m_fe_perm_dir = { fg = c.foam },
    m_fe_perm_file = { fg = c.text },
    m_fe_size = { fg = c.pine },

    ---explorer (filetree)
    m_ft_dirname = { fg = c.subtle },
    m_ft_filename = { fg = c.text },
    m_ft_git_add = { fg = c.pine, bold = true },
    m_ft_git_add_cl = { fg = c.pine, bg = c.highlightMed, bold = true },
    m_ft_git_add_clb = { fg = c.pine, bg = c.overlay, bold = true },
    m_ft_git_change = { fg = c.gold, bold = true },
    m_ft_git_change_cl = { fg = c.gold, bg = c.highlightMed, bold = true },
    m_ft_git_change_clb = { fg = c.gold, bg = c.overlay, bold = true },
    m_ft_git_delete = { fg = c.love, bold = true },
    m_ft_git_delete_cl = { fg = c.love, bg = c.highlightMed, bold = true },
    m_ft_git_delete_clb = { fg = c.love, bg = c.overlay, bold = true },
    m_ft_git_ignored = { fg = c.muted, bold = true },
    m_ft_git_ignored_cl = { fg = c.text, bg = c.highlightMed, bold = true },
    m_ft_git_ignored_clb = { fg = c.text, bg = c.overlay, bold = true },
    m_ft_git_other = { fg = c.muted, bold = true },
    m_ft_git_other_cl = { fg = c.text, bg = c.highlightMed, bold = true },
    m_ft_git_other_clb = { fg = c.text, bg = c.overlay, bold = true },
    m_ft_git_rename = { fg = c.foam, bold = true },
    m_ft_git_rename_cl = { fg = c.foam, bg = c.highlightMed, bold = true },
    m_ft_git_rename_clb = { fg = c.foam, bg = c.overlay, bold = true },
    m_ft_git_staged = { fg = c.pine, bold = true },
    m_ft_git_staged_cl = { fg = c.pine, bg = c.highlightMed, bold = true },
    m_ft_git_staged_clb = { fg = c.pine, bg = c.overlay, bold = true },
    m_ft_git_unmerged = { fg = c.gold, bold = true },
    m_ft_git_unmerged_cl = { fg = c.gold, bg = c.highlightMed, bold = true },
    m_ft_git_unmerged_clb = { fg = c.gold, bg = c.overlay, bold = true },
    m_ft_git_unstaged = { fg = c.gold, bold = true },
    m_ft_git_unstaged_cl = { fg = c.gold, bg = c.highlightMed, bold = true },
    m_ft_git_unstaged_clb = { fg = c.gold, bg = c.overlay, bold = true },
    m_ft_git_untracked = { fg = c.muted, bold = true },
    m_ft_git_untracked_cl = { fg = c.text, bg = c.highlightMed, bold = true },
    m_ft_git_untracked_clb = { fg = c.text, bg = c.overlay, bold = true },
    m_ft_pathsep = { fg = c.muted },
    m_ft_position = { fg = c.subtle },
    m_ft_reference = { fg = c.iris, bold = true, italic = true },
    m_ft_text = { fg = c.muted },
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
