---@class ark.theme.hlgroup.vsc.module
local M = {}

---@param context                       ark.t.theme.IContext
---@return table<string, ark.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local u = context.scheme.palette.unified ---@type ark.t.theme.IUnifiedPalette
  local c = context.scheme.palette.vsc ---@type ark.t.theme.IVscPalette
  local t = context.transparency ---@type boolean

  local bg = t and c.none or u.bg0 ---@type string
  local bg_pane = t and u.bg0 or c.none ---@type string
  local badge_fg = u.bg1 ---@type string
  local panel_bg = cs.mix(t and c.none or c.base, t and c.none or c.overlay, 60) ---@type string

  return {
    ---module/ai
    m_ai_attached = { fg = u.pink, bold = true },
    m_ai_loc_col = { fg = c.accentAqua },
    m_ai_loc_delim = { fg = u.fg4 },
    m_ai_loc_file = { fg = c.accentBlue },
    m_ai_loc_num = { fg = c.tokenConstantNumeric },
    m_ai_loc_row = { fg = c.accentPurple },
    m_ai_new = { fg = u.fg2 },
    m_ai_prompt_header = { fg = c.accentPurple, bold = true },
    m_ai_running_agent_session = { fg = u.aqua, bold = true },
    m_ai_running_other_session = { fg = u.fg0, bold = true },
    m_ai_running_same_session = { fg = u.fg0, bold = true },
    m_ai_running_same_window = { fg = u.blue, bold = true },
    m_ai_send_to_all = { fg = u.red, bold = true },

    ---module/board/fileinfo
    m_bf_label = { fg = c.textDim },
    m_bf_normal = { fg = c.text, bg = bg_pane },
    m_bf_value = { fg = c.accentBlue },

    ---module/board/git-hunk
    m_bgh_header = { fg = c.accentPurple, bold = true },

    ---module/board/keysheet
    m_bk_border = { fg = c.widget_border, bg = bg_pane },
    m_bk_cursorline = { bg = u.bg2 },
    m_bk_desc = { fg = c.text },
    m_bk_key = { fg = c.accentBlue, bold = true },
    m_bk_mode = { fg = c.accentOrange },
    m_bk_normal = { fg = c.text, bg = bg_pane },
    m_bk_title = { fg = c.accentPurple, bg = bg_pane, bold = true },

    ---module/choice
    m_ch_current = { bg = u.bg3 },
    m_ch_key = { fg = c.accentPink, bold = true },
    m_ch_normal = { fg = c.text, bg = bg_pane },
    m_ch_sign_current = { fg = c.accentAqua, bg = u.bg3 },
    m_ch_text = { fg = c.text },

    ---module/colorpicker
    m_cp_bar_name = { fg = c.textDim, bg = bg_pane },
    m_cp_bar_value = { fg = c.text, bg = bg_pane },
    m_cp_border = { fg = c.widget_border, bg = bg_pane },
    m_cp_normal = { fg = c.text, bg = bg_pane },
    m_cp_output_mode = { fg = c.textDim, bg = bg_pane },
    m_cp_point = { fg = c.text, bold = true },
    m_cp_point_dark = { fg = c.base, bold = true },
    m_cp_point_light = { fg = c.text, bold = true },
    m_cp_preview_after = { fg = c.text, bg = c.editorWidget_background },
    m_cp_preview_before = { fg = c.text, bg = c.editorWidget_background },
    m_cp_title = { fg = c.accentPurple, bg = bg_pane, bold = true },

    ---module/explorer
    m_ex_bg = { fg = c.text, bg = bg },
    m_ex_border = { fg = c.widget_border, bg = bg },
    m_ex_copy = { fg = c.accentYellow, italic = true },
    m_ex_copy_cl = { fg = c.accentYellow, bg = u.bg3, italic = true },
    m_ex_copy_clb = { fg = c.accentYellow, bg = u.bg2, italic = true },
    m_ex_cursorline = { bg = u.bg3 },
    m_ex_cursorline_blur = { bg = u.bg2 },
    m_ex_cut = { fg = c.accentRed, italic = true },
    m_ex_cut_cl = { fg = c.accentRed, bg = u.bg3, italic = true },
    m_ex_cut_clb = { fg = c.accentRed, bg = u.bg2, italic = true },
    m_ex_eob = { fg = bg, bg = bg },
    m_ex_ignored = { fg = u.fg4, italic = true },
    m_ex_indent = { fg = u.bg3 },
    m_ex_selected = { fg = c.accentYellow, bold = true },
    m_ex_selected_cl = { fg = c.accentYellow, bg = u.bg3, bold = true },
    m_ex_selected_clb = { fg = c.accentYellow, bg = u.bg2, bold = true },
    m_ex_winbar = { fg = c.text, bg = c.tab_inactiveBackground, bold = true },

    ---module/explorer (file explorer)
    m_fe_date = { fg = u.fg4 },
    m_fe_group = { fg = u.red },
    m_fe_name_dir = { fg = u.blue },
    m_fe_name_file = { fg = u.fg1 },
    m_fe_owner = { fg = u.red },
    m_fe_perm = { fg = u.fg1 },
    m_fe_perm_dir = { fg = u.blue },
    m_fe_perm_file = { fg = u.fg1 },
    m_fe_size = { fg = u.green },

    ---module/explorer (filetree)
    m_ft_dirname = { fg = u.brightBlue },
    m_ft_filename = { fg = u.fg1 },
    m_ft_git_add = { fg = u.brightGreen, bold = true },
    m_ft_git_add_cl = { fg = u.brightGreen, bg = u.bg3, bold = true },
    m_ft_git_add_clb = { fg = u.brightGreen, bg = u.bg2, bold = true },
    m_ft_git_change = { fg = u.brightYellow, bold = true },
    m_ft_git_change_cl = { fg = u.brightYellow, bg = u.bg3, bold = true },
    m_ft_git_change_clb = { fg = u.brightYellow, bg = u.bg2, bold = true },
    m_ft_git_delete = { fg = u.brightRed, bold = true },
    m_ft_git_delete_cl = { fg = u.brightRed, bg = u.bg3, bold = true },
    m_ft_git_delete_clb = { fg = u.brightRed, bg = u.bg2, bold = true },
    m_ft_git_ignored = { fg = u.fg3, bold = true },
    m_ft_git_ignored_cl = { fg = u.fg3, bg = u.bg3, bold = true },
    m_ft_git_ignored_clb = { fg = u.fg3, bg = u.bg2, bold = true },
    m_ft_git_other = { fg = u.fg3, bold = true },
    m_ft_git_other_cl = { fg = u.fg3, bg = u.bg3, bold = true },
    m_ft_git_other_clb = { fg = u.fg3, bg = u.bg2, bold = true },
    m_ft_git_rename = { fg = u.brightBlue, bold = true },
    m_ft_git_rename_cl = { fg = u.brightBlue, bg = u.bg3, bold = true },
    m_ft_git_rename_clb = { fg = u.brightBlue, bg = u.bg2, bold = true },
    m_ft_git_staged = { fg = u.brightGreen, bold = true },
    m_ft_git_staged_cl = { fg = u.brightGreen, bg = u.bg3, bold = true },
    m_ft_git_staged_clb = { fg = u.brightGreen, bg = u.bg2, bold = true },
    m_ft_git_unmerged = { fg = u.brightOrange, bold = true },
    m_ft_git_unmerged_cl = { fg = u.brightOrange, bg = u.bg3, bold = true },
    m_ft_git_unmerged_clb = { fg = u.brightOrange, bg = u.bg2, bold = true },
    m_ft_git_unstaged = { fg = u.brightYellow, bold = true },
    m_ft_git_unstaged_cl = { fg = u.brightYellow, bg = u.bg3, bold = true },
    m_ft_git_unstaged_clb = { fg = u.brightYellow, bg = u.bg2, bold = true },
    m_ft_git_untracked = { fg = u.fg4, bold = true },
    m_ft_git_untracked_cl = { fg = u.fg4, bg = u.bg3, bold = true },
    m_ft_git_untracked_clb = { fg = u.fg4, bg = u.bg2, bold = true },
    m_ft_pathsep = { fg = u.fg4 },
    m_ft_position = { fg = u.bg4 },
    m_ft_reference = { fg = u.purple, bold = true, italic = true },
    m_ft_text = { fg = u.fg4 },

    ---module/git (hunk preview)
    m_ghp_cursor = { bg = u.bg3 },
    m_ghp_normal = { bg = u.bg1 },

    ---module/git (signs, blame)
    m_git_buffer_blame = { fg = cs.mix(c.editor_background, c.textDim, 30), italic = true },
    m_git_hunk_indicator = { fg = c.editorGutter_modifiedBackground },
    m_git_inline_blame = { fg = cs.mix(c.editor_background, c.textDim, 60), italic = true },
    m_git_sign_add = { fg = c.editorGutter_addedBackground },
    m_git_sign_add_staged = { fg = cs.mix(c.editor_background, c.editorGutter_addedBackground, 50) },
    m_git_sign_change = { fg = c.editorGutter_modifiedBackground },
    m_git_sign_change_staged = { fg = cs.mix(c.editor_background, c.editorGutter_modifiedBackground, 50) },
    m_git_sign_delete = { fg = c.editorGutter_deletedBackground },
    m_git_sign_delete_staged = { fg = cs.mix(c.editor_background, c.editorGutter_deletedBackground, 50) },
    m_git_sign_untracked = { fg = c.success },

    ---module/image
    m_img_anchor = { fg = c.accentPurple },
    m_img_border = { link = "ms_b_none" },
    m_img_loading = { fg = c.textDim },
    m_img_math = { fg = c.accentPurple },
    m_img_special = { fg = c.accentPurple },
    m_img_spinner = { fg = c.textDim },

    ---module/input
    m_in_current = { bg = u.bg3 },
    m_in_normal = { bg = bg_pane },

    ---module/picker
    m_pk_finder_normal = { fg = u.fg1, bg = bg_pane },
    m_pk_finder_prompt = { fg = u.red, bg = bg_pane },
    m_pk_finder_title = { link = t and "ms_b_bg0" or "ms_b_none" },
    m_pk_matches = { fg = u.pink, bold = true, italic = true },
    m_pk_preview_current = { bg = u.bg2 },
    m_pk_preview_normal = { bg = bg_pane },
    m_pk_preview_title = { fg = u.green, bg = bg_pane, bold = true },
    m_pk_replacer_prompt = { fg = u.brightBlue, bg = bg_pane },
    m_pk_result_current = { bg = u.bg3 },
    m_pk_result_normal = { bg = bg_pane },
    m_pk_sign_line_current = { bg = u.bg3 },
    m_pk_sign_line_present = { fg = u.pink, bg = c.none, bold = true },
    m_pk_sign_line_present_current = { fg = u.pink, bg = u.bg3, bold = true },
    m_pk_sign_line_selected = { fg = u.purple, bg = c.none },
    m_pk_sign_line_selected_current = { fg = u.purple, bg = u.bg3 },

    ---module/plugin
    m_pl_bold = { bold = true },
    m_pl_button = { fg = c.text, bg = c.none },
    m_pl_button_active = { fg = u.pink, bg = c.none },
    m_pl_cmd = { fg = c.accentBlue },
    m_pl_comment = { fg = c.textMuted, italic = true },
    m_pl_commit = { fg = c.accentBlue },
    m_pl_commit_from = { fg = c.accentRed },
    m_pl_commit_msg = { fg = c.text },
    m_pl_commit_time = { fg = c.textMuted, italic = true },
    m_pl_commit_to = { fg = c.accentGreen },
    m_pl_commit_type = { fg = c.accentPurple, bold = true },
    m_pl_dep = { fg = c.textMuted, italic = true },
    m_pl_error = { fg = c.accentRed },
    m_pl_event = { fg = c.accentYellow },
    m_pl_ft = { fg = c.accentAqua },
    m_pl_h1 = { fg = badge_fg, bg = u.pink, bold = true },
    m_pl_h2 = { fg = c.text, bold = true, underline = true },
    m_pl_icon_cmd = { fg = c.accentBlue },
    m_pl_icon_dep = { fg = c.accentRed },
    m_pl_icon_event = { fg = c.accentYellow },
    m_pl_icon_ft = { fg = c.accentAqua },
    m_pl_icon_key = { fg = c.accentGreen },
    m_pl_icon_source = { fg = c.accentPurple },
    m_pl_key = { fg = c.accentGreen },
    m_pl_loaded = { fg = c.success },
    m_pl_normal = { fg = c.text, bg = panel_bg, blend = t and 0 or 40 },
    m_pl_not_loaded = { fg = c.textMuted },
    m_pl_running = { fg = c.accentYellow },
    m_pl_source = { fg = c.accentPurple },
    m_pl_time = { fg = c.accentPurple },

    ---module/searcher
    m_ss_matches = { fg = u.pink, bold = true, italic = true },
    m_ss_replace = { fg = u.green, bold = true, italic = true },
    m_ss_search = { fg = u.red, bold = true, italic = true, strikethrough = true },

    ---module/searcher (search & replace)
    m_sr_error = { fg = u.red, bold = true },
    m_sr_match = { fg = u.bg1, bg = u.yellow },
    m_sr_match_cur = { fg = u.bg1, bg = u.red, bold = true, underline = true },
    m_sr_replace = { fg = u.fg1, bg = u.diffAdd },
    m_sr_replace_cur = { fg = u.bg1, bg = u.brightGreen, bold = true },
    m_sr_search = { fg = u.fg1, bg = u.diffDel, strikethrough = true },
    m_sr_search_cur = { fg = u.bg1, bg = u.red, bold = true, strikethrough = true },

    ---module/term
    m_term_bg = { bg = u.bg0 },
    m_term_current = { bg = u.bg2 },

    ---era/dressing/select/codeaction
    m_sca_client_name = { fg = u.fg4, bg = c.none },
    m_sca_content = { fg = u.fg1, bg = c.none },
    m_sca_order = { fg = u.red, bg = c.none },

    ---dot/fn/find-keymaps
    m_skm_desc = { fg = u.fg2 },
    m_skm_label = { fg = u.fg4 },
    m_skm_lhs = { fg = u.blue, bold = true },
    m_skm_mode = { fg = u.orange },
    m_skm_rhs = { fg = u.green },
    m_skm_source = { fg = u.purple },

    ---dot/fn/find-vim-options
    m_fvo_name = { fg = u.fg1 },
    m_fvo_scope = { fg = u.red, bold = true },
    m_fvo_type = { fg = u.orange },
    m_fvo_value = { fg = u.fg3 },
  }
end

return M
