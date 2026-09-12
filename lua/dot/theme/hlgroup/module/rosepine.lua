---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.module.rosepine" ---@type string

---@class dot.theme.hlgroup.module.rosepine
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local cs = stl.color
  local c = context.scheme.palette.rosepine ---@type stl.t.theme.IRosepinePalette
  local t = context.transparency ---@type boolean

  local bg = t and c.none or c.base ---@type string
  local bg_pane = t and c.base or c.none ---@type string

  -- Tint diff fills from the native palette, independent of window transparency.
  local diff_add = cs.mix(c.base, c.pine, 15)
  local diff_del = cs.mix(c.base, c.love, 15)
  local diff_add_inline = cs.mix(c.base, c.pine, 30)
  local diff_del_inline = cs.mix(c.base, c.love, 30)

  return {
    ---module/ai
    m_ai_args_tag = { fg = c.base, bg = c.rose },
    m_ai_args_tag_sep = { fg = c.rose, bg = c.none },
    m_ai_attached = { fg = c.rose, bold = true },
    m_ai_loc_col = { fg = c.rose },
    m_ai_loc_delim = { fg = c.muted },
    m_ai_loc_file = { fg = c.foam },
    m_ai_loc_num = { fg = c.gold },
    m_ai_loc_row = { fg = c.iris },
    m_ai_new = { fg = c.subtle },
    m_ai_prompt_header = { fg = c.iris, bold = true },
    m_ai_running_agent_session = { fg = c.rose, bold = true },
    m_ai_running_other_session = { fg = c.text, bold = true },
    m_ai_running_same_session = { fg = c.text, bold = true },
    m_ai_running_same_window = { fg = c.foam, bold = true },
    m_ai_send_to_all = { fg = c.love, bold = true },

    ---module/board/fileinfo
    m_bf_label = { fg = c.muted },
    m_bf_normal = { fg = c.text, bg = bg_pane },
    m_bf_value = { fg = c.foam },

    ---module/board/git-hunk
    m_bgh_header = { fg = c.iris, bold = true },

    ---module/board/keysheet
    m_bk_border = { fg = c.highlightHigh, bg = bg_pane },
    m_bk_cursorline = { bg = c.overlay },
    m_bk_desc = { fg = c.subtle },
    m_bk_key = { fg = c.foam, bold = true },
    m_bk_mode = { fg = c.gold },
    m_bk_normal = { fg = c.text, bg = bg_pane },
    m_bk_title = { fg = c.iris, bg = bg_pane, bold = true },

    ---module/choice
    m_ch_current = { bg = c.highlightMed },
    m_ch_key = { fg = c.rose, bold = true },
    m_ch_normal = { fg = c.text, bg = bg_pane },
    m_ch_sign_current = { fg = c.rose, bg = c.highlightMed },
    m_ch_text = { fg = c.subtle },

    ---module/colorpicker
    m_cp_bar_name = { fg = c.muted, bg = bg_pane },
    m_cp_bar_value = { fg = c.subtle, bg = bg_pane },
    m_cp_border = { fg = c.highlightHigh, bg = bg_pane },
    m_cp_normal = { fg = c.text, bg = bg_pane },
    m_cp_output_mode = { fg = c.muted, bg = bg_pane },
    m_cp_point = { fg = c.text, bold = true },
    m_cp_point_dark = { fg = c.base, bold = true },
    m_cp_point_light = { fg = c.text, bold = true },
    m_cp_preview_after = { fg = c.text, bg = c.highlightMed },
    m_cp_preview_before = { fg = c.text, bg = c.highlightMed },
    m_cp_title = { fg = c.iris, bg = bg_pane, bold = true },

    ---module/explorer
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
    m_ex_selected = { fg = c.gold, bold = true },
    m_ex_selected_cl = { fg = c.gold, bg = c.highlightMed, bold = true },
    m_ex_selected_clb = { fg = c.gold, bg = c.overlay, bold = true },
    m_ex_winbar = { fg = c.subtle, bg = c.surface, bold = true },

    ---module/explorer (file explorer)
    m_fe_date = { fg = c.muted },
    m_fe_group = { fg = c.love },
    m_fe_name_dir = { fg = c.rose },
    m_fe_name_file = { fg = c.text },
    m_fe_owner = { fg = c.love },
    m_fe_perm = { fg = c.text },
    m_fe_perm_dir = { fg = c.foam },
    m_fe_perm_file = { fg = c.text },
    m_fe_size = { fg = c.pine },

    ---module/explorer (filetree)
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

    ---module/git (hunk preview)
    m_ghp_cursor = { bg = c.highlightMed },
    m_ghp_normal = { bg = c.surface },

    ---module/git (signs, blame)
    m_git_buffer_blame = { fg = c.subtle, italic = true },
    m_git_hunk_indicator = { fg = c.love },
    m_git_inline_blame = { fg = c.muted, italic = true },
    m_git_sign_add = { fg = c.pine },
    m_git_sign_add_staged = { fg = cs.mix(c.base, c.pine, 80) },
    m_git_sign_change = { fg = c.gold },
    m_git_sign_change_staged = { fg = cs.mix(c.base, c.gold, 80) },
    m_git_sign_delete = { fg = c.love },
    m_git_sign_delete_staged = { fg = cs.mix(c.base, c.love, 80) },
    m_git_sign_untracked = { fg = c.muted },

    ---module/image
    m_img_anchor = { fg = c.iris },
    m_img_loading = { fg = c.muted },
    m_img_math = { fg = c.rose, bold = true },
    m_img_special = { fg = c.iris },
    m_img_spinner = { fg = c.muted },

    ---module/input
    m_in_current = { bg = c.highlightMed },
    m_in_normal = { bg = bg_pane },

    ---module/notifications
    m_nf_body = { fg = c.text },
    m_nf_current = { bg = c.highlightMed },
    m_nf_icon_debug = { fg = c.muted },
    m_nf_icon_error = { fg = c.love },
    m_nf_icon_info = { fg = c.foam },
    m_nf_icon_trace = { fg = c.muted },
    m_nf_icon_warn = { fg = c.gold },
    m_nf_level_debug = { fg = c.muted },
    m_nf_level_error = { fg = c.love },
    m_nf_level_info = { fg = c.foam },
    m_nf_level_trace = { fg = c.muted },
    m_nf_level_warn = { fg = c.gold },
    m_nf_normal = { fg = c.text, bg = bg_pane },
    m_nf_time = { fg = c.muted },
    m_nf_title_debug = { fg = c.subtle },
    m_nf_title_error = { fg = c.love },
    m_nf_title_info = { fg = c.text },
    m_nf_title_trace = { fg = c.muted },
    m_nf_title_warn = { fg = c.gold },

    ---module/picker
    m_pk_finder_normal = { fg = c.text, bg = bg_pane },
    m_pk_finder_prompt = { fg = c.love, bg = bg_pane },
    m_pk_finder_title = { link = t and "ms_b_bg0" or "ms_b_none" },
    m_pk_matches = { fg = c.rose, bold = true, italic = true },
    m_pk_preview_current = { bg = c.overlay },
    m_pk_preview_normal = { bg = bg_pane },
    m_pk_preview_title = { fg = c.pine, bg = bg_pane, bold = true },
    m_pk_replacer_prompt = { fg = c.foam, bg = bg_pane },
    m_pk_result_current = { bg = c.highlightMed },
    m_pk_result_normal = { bg = bg_pane },
    m_pk_search_spinner_aqua = { fg = c.rose, bg = bg_pane, bold = true },
    m_pk_search_spinner_blue = { fg = c.foam, bg = bg_pane, bold = true },
    m_pk_search_spinner_pink = { fg = c.rose, bg = bg_pane, bold = true },
    m_pk_search_spinner_purple = { fg = c.iris, bg = bg_pane, bold = true },
    m_pk_sign_line_current = { bg = c.highlightMed },
    m_pk_sign_line_present = { fg = c.rose, bg = c.none, bold = true },
    m_pk_sign_line_present_current = { fg = c.rose, bg = c.highlightMed, bold = true },
    m_pk_sign_line_selected = { fg = c.iris, bg = c.none },
    m_pk_sign_line_selected_current = { fg = c.iris, bg = c.highlightMed },

    ---module/plugin
    m_pl_bold = { bold = true },
    m_pl_cmd = { fg = c.foam },
    m_pl_comment = { fg = c.muted, italic = true },
    m_pl_commit = { fg = c.foam },
    m_pl_commit_from = { fg = c.love },
    m_pl_commit_msg = { fg = c.subtle },
    m_pl_commit_time = { fg = c.muted, italic = true },
    m_pl_commit_to = { fg = c.pine },
    m_pl_commit_type = { fg = c.iris, bold = true },
    m_pl_dep = { fg = c.muted, italic = true },
    m_pl_error = { fg = c.love },
    m_pl_event = { fg = c.gold },
    m_pl_ft = { fg = c.rose },
    m_pl_h2 = { fg = c.subtle, bold = true, underline = true },
    m_pl_icon_cmd = { fg = c.foam },
    m_pl_icon_dep = { fg = c.love },
    m_pl_icon_event = { fg = c.gold },
    m_pl_icon_ft = { fg = c.rose },
    m_pl_icon_key = { fg = c.pine },
    m_pl_icon_source = { fg = c.iris },
    m_pl_key = { fg = c.pine },
    m_pl_loaded = { fg = c.pine },
    m_pl_normal = { fg = c.text, bg = c.surface, blend = t and 50 or 0 },
    m_pl_not_loaded = { fg = c.muted },
    m_pl_output = { fg = c.muted },
    m_pl_running = { fg = c.gold },
    m_pl_source = { fg = c.iris },
    m_pl_step = { fg = c.rose },
    m_pl_time = { fg = c.iris },
    m_pl_title = { fg = c.iris, bold = true },

    ---module/searcher
    m_ss_matches = { fg = c.rose, bold = true, italic = true },
    m_ss_replace = { fg = c.pine, bold = true, italic = true },
    m_ss_search = { fg = c.love, bold = true, italic = true, strikethrough = true },

    ---module/searcher (search & replace)
    m_sr_error = { fg = c.love, bold = true },
    m_sr_match = { fg = c.surface, bg = c.gold },
    m_sr_match_cur = { fg = c.surface, bg = c.love, bold = true, underline = true },
    m_sr_replace = { fg = c.text, bg = diff_add },
    m_sr_replace_cur = { fg = c.surface, bg = c.pine, bold = true },
    m_sr_search = { fg = c.text, bg = diff_del, strikethrough = true },
    m_sr_search_cur = { fg = c.surface, bg = c.love, bold = true, strikethrough = true },

    ---module/term
    m_term_bg = { bg = c.base },
    m_term_current = { bg = c.overlay },

    ---era/m/select/provider-codeaction
    m_sca_client_name = { fg = c.muted, bg = c.none },
    m_sca_content = { fg = c.text, bg = c.none },
    m_sca_order = { fg = c.love, bg = c.none },

    ---dot/fn/find-keymaps
    m_skm_desc = { fg = c.subtle },
    m_skm_label = { fg = c.muted },
    m_skm_lhs = { fg = c.foam, bold = true },
    m_skm_mode = { fg = c.gold },
    m_skm_rhs = { fg = c.pine },
    m_skm_source = { fg = c.iris },

    ---dot/fn/find-vim-options
    m_fvo_name = { fg = c.text },
    m_fvo_scope = { fg = c.love, bold = true },
    m_fvo_type = { fg = c.gold },
    m_fvo_value = { fg = c.muted },

    ---module/diffview (panel common)
    m_dv_cursorline = { bg = c.highlightMed },
    m_dv_eob = { fg = bg, bg = bg },
    m_dv_normal = { fg = c.text, bg = bg },
    m_dv_winbar = { fg = c.subtle, bg = c.surface, bold = true },
    m_dv_winbar_dim = { fg = c.subtle, bg = c.surface },
    m_dv_winbar_flag_aqua = { fg = c.base, bg = c.rose },
    m_dv_winbar_flag_blue = { fg = c.base, bg = c.foam },
    m_dv_winbar_flag_dim = { fg = c.muted, bg = c.overlay },
    m_dv_winbar_flag_green = { fg = c.base, bg = c.pine },
    m_dv_winbar_flag_purple = { fg = c.base, bg = c.iris },
    m_dv_winbar_flag_red = { fg = c.base, bg = c.love },
    m_dv_winsep = { fg = c.highlightMed, bg = bg },

    ---module/diffview (diff highlights for sbs view)
    m_dv_add = { bg = diff_add },
    m_dv_add_dim = { bg = diff_add },
    m_dv_add_inline = { fg = c.text, bg = diff_add_inline },
    m_dv_del = { bg = diff_del },
    m_dv_del_dim = { bg = diff_del },
    m_dv_del_inline = { fg = c.text, bg = diff_del_inline },

    ---module/diffview (filetree)
    m_dv_ft_deletions = { fg = c.love },
    m_dv_ft_dirname = { fg = c.foam },
    m_dv_ft_filename = { fg = c.subtle },
    m_dv_ft_insertions = { fg = c.pine },
    m_dv_ft_separator = { fg = c.highlightHigh },
    m_dv_ft_status_add = { fg = c.pine },
    m_dv_ft_status_delete = { fg = c.love },
    m_dv_ft_status_modify = { fg = c.gold },
    m_dv_ft_status_rename = { fg = c.foam },
    m_dv_ft_status_unmerged = { fg = c.gold },
    m_dv_ft_status_untracked = { fg = c.muted },

    ---module/diffview (commits)
    m_dv_cm_author = { fg = c.iris },
    m_dv_cm_current = { bg = c.highlightMed },
    m_dv_cm_date = { fg = c.muted },
    m_dv_cm_files = { fg = c.rose },
    m_dv_cm_graph = { fg = c.foam },
    m_dv_cm_hash = { fg = c.gold },
    m_dv_cm_message = { fg = c.text },
    m_dv_cm_sep = { fg = c.highlightHigh },

    ---module/diffview (sign)
    m_dv_sign_present = { fg = c.rose, bg = c.none, bold = true },

    ---module/wk
    m_wk_desc = { fg = c.text },
    m_wk_group = { fg = c.foam },
    m_wk_icon_azure = { fg = c.foam },
    m_wk_icon_blue = { fg = c.foam },
    m_wk_icon_cyan = { fg = c.rose },
    m_wk_icon_green = { fg = c.pine },
    m_wk_icon_grey = { fg = c.subtle },
    m_wk_icon_orange = { fg = c.gold },
    m_wk_icon_purple = { fg = c.iris },
    m_wk_icon_red = { fg = c.love },
    m_wk_icon_yellow = { fg = c.gold },
    m_wk_key = { fg = c.foam },
    m_wk_pressed = { fg = c.love, bold = true },
    m_wk_normal = { fg = c.text, bg = t and c.none or c.overlay },
    m_wk_separator = { fg = c.highlightHigh },
  }
end

return M
