---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return table<string, fml.types.ui.theme.IHlgroup|nil>
local function gen_hlgroup(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors
  local t = params.transparency ---@type boolean

  return {
    ---common
    f_transparent = { bg = "none" },

    ---statusline
    f_sl_bg = { fg = t and "none" or c.statusline_bg, bg = t and "none" or c.statusline_bg },
    f_sl_copilot_InProgress = { fg = c.cyan, bg = t and "none" or c.statusline_bg },
    f_sl_copilot_Normal = { fg = c.blue, bg = t and "none" or c.statusline_bg },
    f_sl_copilot_Warning = { fg = c.yellow, bg = t and "none" or c.statusline_bg },
    f_sl_diagnostics_error = { fg = c.red, bg = t and "none" or c.statusline_bg },
    f_sl_diagnostics_hint = { fg = c.purple, bg = t and "none" or c.statusline_bg },
    f_sl_diagnostics_info = { fg = c.green, bg = t and "none" or c.statusline_bg },
    f_sl_diagnostics_warn = { fg = c.yellow, bg = t and "none" or c.statusline_bg },
    f_sl_flag = { fg = c.white, bg = t and "none" or c.grey },
    f_sl_flag_enabled = { fg = c.black, bg = c.nord_blue },
    f_sl_flag_scope = { fg = c.black, bg = c.baby_pink },
    f_sl_noice_command = { fg = c.white, bg = t and "none" or c.statusline_bg },
    f_sl_noice_mode = { fg = c.yellow, bg = t and "none" or c.statusline_bg },
    f_sl_readonly = { fg = c.orange, bg = t and "none" or c.statusline_bg },
    f_sl_text = { fg = c.white, bg = t and "none" or c.statusline_bg },
    f_sl_text_command = { fg = c.vibrant_green, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_confirm = { fg = c.teal, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_insert = { fg = c.dark_purple, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_normal = { fg = c.nord_blue, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_nterminal = { fg = c.yellow, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_replace = { fg = c.orange, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_select = { fg = c.blue, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_terminal = { fg = c.green, bg = t and "none" or c.statusline_bg, bold = true },
    f_sl_text_visual = { fg = c.cyan, bg = t and "none" or c.statusline_bg },
    f_sl_username = { fg = c.black, bg = c.cyan },

    ---tabline
    f_tl_bg = { fg = t and "none" or c.statusline_bg, bg = t and "none" or c.statusline_bg },
    f_tl_buf_item = { fg = c.light_grey, bg = t and "none" or c.black2 },
    f_tl_buf_item_cur = { fg = c.white, bg = t and "none" or c.black },
    f_tl_buf_mod = { fg = c.red, bg = t and "none" or c.black2 },
    f_tl_buf_mod_cur = { fg = c.green, bg = t and "none" or c.black },
    f_tl_buf_title = { fg = c.light_grey, bg = t and "none" or c.black2 },
    f_tl_buf_title_cur = { fg = c.white, bg = t and "none" or c.black },
    f_tl_neotree_blank = { fg = c.white, bg = t and "none" or c.black2 },
    f_tl_neotree_text = { fg = c.white, bg = t and "none" or c.black2 },
    f_tl_tab_add = { fg = c.white, bg = c.one_bg2 },
    f_tl_tab_item = { fg = c.white, bg = c.black2 },
    f_tl_tab_item_cur = { fg = c.red },
    f_tl_tab_toggle = { fg = c.black, bg = c.blue },

    ---diff
    ghc_DiffAdd_left = { bg = "#FFE0E0", fg = "none" },
    ghc_DiffDelete_left = { bg = "#FFE0E0", fg = "none" },
    ghc_DiffChange_left = { bg = "#FFE0E0", fg = "none" },
    ghc_DiffText_left = { bg = "#FFC0C0", fg = "none" },
    ghc_DiffAdd_right = { bg = "#D0FFD0", fg = "none" },
    ghc_DiffDelete_right = { bg = "#FFE0E0", fg = "none" },
    ghc_DiffChange_right = { bg = "#D0FFD0", fg = "none" },
    ghc_DiffText_right = { bg = "#A0EFA0", fg = "none" },

    ---replace
    GhcReplaceFilepath = { fg = c.blue, bg = "none" },
    GhcReplaceFlag = { fg = c.white, bg = c.grey },
    GhcReplaceFlagEnabled = { fg = c.black, bg = c.baby_pink },
    GhcReplaceFence = { fg = c.grey, bg = "none" },
    GhcReplaceInvisible = { fg = "none", bg = "none" },
    GhcReplaceOptName = { fg = c.blue, bg = "none", bold = true },
    GhcReplaceOptReplacePattern = { fg = c.diff_add_hl, bg = "none" },
    GhcReplaceOptSearchPattern = { fg = c.diff_delete_hl, bg = "none" },
    GhcReplaceOptValue = { fg = c.yellow, bg = "none" },
    GhcReplaceTextAdded = { fg = c.diff_add_hl, bg = "none" },
    GhcReplaceTextDeleted = { fg = c.diff_delete_hl, strikethrough = true },
    GhcReplaceUsage = { fg = c.grey_fg2, bg = "none" },

    ---spell
    healthSuccess = { bg = c.green, fg = c.black },
    SpellBad = { undercurl = true, sp = c.base08 },
    SpellCap = { undercurl = true, sp = c.base0D },
    SpellLocal = { undercurl = true, sp = c.base0C },
    SpellRare = { undercurl = true, sp = c.base0E },
  }
end

return gen_hlgroup
