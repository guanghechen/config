---@class dot.theme.hlgroup.module
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local md = string.format("dot.theme.hlgroup.%s.module", context.scheme.theme) ---@type string
  local ok, mod = pcall(require, md)
  if ok and mod then
    return mod.gen_hlgroup_map(context)
  end

  return M.default_gen_hlgroup_map(context)
end

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.default_gen_hlgroup_map(context)
  local cs = stl.color
  local u = context.scheme.palette.unified ---@type stl.t.theme.IUnifiedPalette
  local t = context.transparency ---@type boolean

  local bg = t and u.none or u.bg0 ---@type string
  local bg_pane = t and u.bg0 or u.none ---@type string

  return {
    ---module/ai
    m_ai_attached = { fg = u.pink, bold = true },
    m_ai_loc_col = { fg = u.aqua },
    m_ai_loc_delim = { fg = u.fg4 },
    m_ai_loc_file = { fg = u.blue },
    m_ai_loc_num = { fg = u.orange },
    m_ai_loc_row = { fg = u.purple },
    m_ai_new = { fg = u.fg2 },
    m_ai_prompt_header = { fg = u.purple, bold = true },
    m_ai_running_agent_session = { fg = u.aqua, bold = true },
    m_ai_running_other_session = { fg = u.fg0, bold = true },
    m_ai_running_same_session = { fg = u.fg0, bold = true },
    m_ai_running_same_window = { fg = u.blue, bold = true },
    m_ai_send_to_all = { fg = u.red, bold = true },

    ---module/board/fileinfo
    m_bf_label = { fg = u.fg3 },
    m_bf_normal = { fg = u.fg1, bg = bg_pane },
    m_bf_value = { fg = u.blue },

    ---module/board/git-hunk
    m_bgh_header = { fg = u.purple, bold = true },

    ---module/board/keysheet
    m_bk_border = { fg = u.bg4, bg = bg_pane },
    m_bk_cursorline = { bg = u.bg2 },
    m_bk_desc = { fg = u.fg2 },
    m_bk_key = { fg = u.blue, bold = true },
    m_bk_mode = { fg = u.orange },
    m_bk_normal = { fg = u.fg1, bg = bg_pane },
    m_bk_title = { fg = u.purple, bg = bg_pane, bold = true },

    ---module/choice
    m_ch_current = { bg = u.bg3 },
    m_ch_key = { fg = u.pink, bold = true },
    m_ch_normal = { fg = u.fg1, bg = bg_pane },
    m_ch_sign_current = { fg = u.aqua, bg = u.bg3 },
    m_ch_text = { fg = u.fg2 },

    ---module/colorpicker
    m_cp_bar_name = { fg = u.fg3, bg = bg_pane },
    m_cp_bar_value = { fg = u.fg2, bg = bg_pane },
    m_cp_border = { fg = u.bg4, bg = bg_pane },
    m_cp_normal = { fg = u.fg1, bg = bg_pane },
    m_cp_output_mode = { fg = u.fg4, bg = bg_pane },
    m_cp_point = { fg = u.fg1, bold = true },
    m_cp_point_dark = { fg = u.bg0, bold = true },
    m_cp_point_light = { fg = u.fg0, bold = true },
    m_cp_preview_after = { fg = u.fg1, bg = u.bg3 },
    m_cp_preview_before = { fg = u.fg1, bg = u.bg3 },
    m_cp_title = { fg = u.purple, bg = bg_pane, bold = true },

    ---module/explorer
    m_ex_bg = { fg = u.fg1, bg = bg },
    m_ex_border = { fg = u.bg3, bg = bg },
    m_ex_copy = { fg = u.yellow, italic = true },
    m_ex_copy_cl = { fg = u.yellow, bg = u.bg3, italic = true },
    m_ex_copy_clb = { fg = u.yellow, bg = u.bg2, italic = true },
    m_ex_cursorline = { bg = u.bg3 },
    m_ex_cursorline_blur = { bg = u.bg2 },
    m_ex_cut = { fg = u.red, italic = true },
    m_ex_cut_cl = { fg = u.red, bg = u.bg3, italic = true },
    m_ex_cut_clb = { fg = u.red, bg = u.bg2, italic = true },
    m_ex_eob = { fg = bg, bg = bg },
    m_ex_ignored = { fg = u.fg4 },
    m_ex_indent = { fg = u.bg3 },
    m_ex_selected = { fg = u.brightYellow, bold = true },
    m_ex_selected_cl = { fg = u.brightYellow, bg = u.bg3, bold = true },
    m_ex_selected_clb = { fg = u.brightYellow, bg = u.bg2, bold = true },
    m_ex_winbar = { fg = u.fg2, bg = u.bg1, bold = true },

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
    m_ft_filename = { fg = u.fg2 },
    m_ft_git_add = { fg = u.brightGreen, bold = true },
    m_ft_git_add_cl = { fg = u.brightGreen, bg = u.bg3, bold = true },
    m_ft_git_add_clb = { fg = u.brightGreen, bg = u.bg2, bold = true },
    m_ft_git_change = { fg = u.brightYellow, bold = true },
    m_ft_git_change_cl = { fg = u.brightYellow, bg = u.bg3, bold = true },
    m_ft_git_change_clb = { fg = u.brightYellow, bg = u.bg2, bold = true },
    m_ft_git_delete = { fg = u.brightRed, bold = true },
    m_ft_git_delete_cl = { fg = u.brightRed, bg = u.bg3, bold = true },
    m_ft_git_delete_clb = { fg = u.brightRed, bg = u.bg2, bold = true },
    m_ft_git_ignored = { fg = u.fg4, bold = true },
    m_ft_git_ignored_cl = { fg = u.fg4, bg = u.bg3, bold = true },
    m_ft_git_ignored_clb = { fg = u.fg4, bg = u.bg2, bold = true },
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
    m_git_buffer_blame = { fg = u.bg4, italic = true },
    m_git_hunk_indicator = { fg = u.orange },
    m_git_inline_blame = { fg = u.fg4, italic = true },
    m_git_sign_add = { fg = u.green },
    m_git_sign_add_staged = { fg = cs.mix(u.bg0, u.green, 50) },
    m_git_sign_change = { fg = u.blue },
    m_git_sign_change_staged = { fg = cs.mix(u.bg0, u.blue, 50) },
    m_git_sign_delete = { fg = u.red },
    m_git_sign_delete_staged = { fg = cs.mix(u.bg0, u.red, 50) },
    m_git_sign_untracked = { fg = u.fg4 },

    ---module/image
    m_img_anchor = { fg = u.purple },
    m_img_border = { link = "ms_b_none" },
    m_img_loading = { fg = u.fg4 },
    m_img_math = { fg = u.purple },
    m_img_special = { fg = u.purple },
    m_img_spinner = { fg = u.fg4 },

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
    m_pk_sign_line_present = { fg = u.pink, bg = u.none, bold = true },
    m_pk_sign_line_present_current = { fg = u.pink, bg = u.bg3, bold = true },
    m_pk_sign_line_selected = { fg = u.purple, bg = u.none },
    m_pk_sign_line_selected_current = { fg = u.purple, bg = u.bg3 },

    ---module/plugin
    m_pl_bold = { bold = true },
    m_pl_button = { fg = u.fg2, bg = u.none },
    m_pl_button_active = { fg = u.pink, bg = u.none },
    m_pl_cmd = { fg = u.blue },
    m_pl_comment = { fg = u.fg4, italic = true },
    m_pl_commit = { fg = u.blue },
    m_pl_commit_from = { fg = u.red },
    m_pl_commit_msg = { fg = u.fg2 },
    m_pl_commit_time = { fg = u.fg4, italic = true },
    m_pl_commit_to = { fg = u.green },
    m_pl_commit_type = { fg = u.purple, bold = true },
    m_pl_dep = { fg = u.fg4, italic = true },
    m_pl_error = { fg = u.red },
    m_pl_event = { fg = u.yellow },
    m_pl_ft = { fg = u.aqua },
    m_pl_h1 = { fg = u.bg1, bg = u.pink, bold = true },
    m_pl_h2 = { fg = u.fg2, bold = true, underline = true },
    m_pl_icon_cmd = { fg = u.blue },
    m_pl_icon_dep = { fg = u.red },
    m_pl_icon_event = { fg = u.yellow },
    m_pl_icon_ft = { fg = u.aqua },
    m_pl_icon_key = { fg = u.green },
    m_pl_icon_source = { fg = u.purple },
    m_pl_key = { fg = u.green },
    m_pl_loaded = { fg = u.green },
    m_pl_normal = { bg = cs.mix(u.bg0, u.bg1, 80), blend = 50 },
    m_pl_not_loaded = { fg = u.fg4 },
    m_pl_running = { fg = u.yellow },
    m_pl_source = { fg = u.purple },
    m_pl_step = { fg = u.aqua },
    m_pl_time = { fg = u.purple },
    m_pl_title = { fg = u.purple, bold = true },

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

    ---era/m/select/provider-codeaction
    m_sca_client_name = { fg = u.fg4, bg = u.none },
    m_sca_content = { fg = u.fg1, bg = u.none },
    m_sca_order = { fg = u.red, bg = u.none },

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

    ---module/wk
    m_wk_desc = { fg = u.fg3 },
    m_wk_group = { fg = u.blue },
    m_wk_icon_azure = { fg = u.blue },
    m_wk_icon_blue = { fg = u.blue },
    m_wk_icon_cyan = { fg = u.aqua },
    m_wk_icon_green = { fg = u.green },
    m_wk_icon_grey = { fg = u.bg4 },
    m_wk_icon_orange = { fg = u.orange },
    m_wk_icon_purple = { fg = u.purple },
    m_wk_icon_red = { fg = u.red },
    m_wk_icon_yellow = { fg = u.yellow },
    m_wk_key = { fg = u.blue },
    m_wk_pressed = { fg = u.red, bold = true },
    m_wk_normal = { fg = u.fg1, bg = t and u.none or u.bg2 },
    m_wk_separator = { fg = u.bg4 },
  }
end

return M
