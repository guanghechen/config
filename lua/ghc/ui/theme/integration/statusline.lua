---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return ghc.ui.theme.integration.statusline.hlgroups
local function gen_hlgroup_map(params)
  local c = params.scheme.colors ---@type fml.types.ui.theme.IColors
  local t = params.transparency ---@type boolean

  local mode_bg = t and "none" or c.one_bg ---@type string

  ---@class ghc.ui.theme.integration.statusline.hlgroups : table<string, fml.types.ui.theme.IHlgroup>
  local hlgroup_map = {
    f_sl_bg = { fg = t and "none" or c.bg_statusline, bg = t and "none" or c.bg_statusline },
    f_sl_copilot_InProgress = { fg = c.cyan, bg = t and "none" or c.bg_statusline },
    f_sl_copilot_Inactive = { fg = c.red, bg = t and "none" or c.bg_statusline },
    f_sl_copilot_Normal = { fg = c.blue, bg = t and "none" or c.bg_statusline },
    f_sl_copilot_Warning = { fg = c.yellow, bg = t and "none" or c.bg_statusline },
    f_sl_diagnostics_error = { fg = c.red, bg = t and "none" or c.bg_statusline },
    f_sl_diagnostics_hint = { fg = c.purple, bg = t and "none" or c.bg_statusline },
    f_sl_diagnostics_info = { fg = c.green, bg = t and "none" or c.bg_statusline },
    f_sl_diagnostics_warn = { fg = c.yellow, bg = t and "none" or c.bg_statusline },
    f_sl_flag = { fg = c.white, bg = t and "none" or c.grey },
    f_sl_flag_enabled = { fg = c.black, bg = c.nord_blue },
    f_sl_flag_scope = { fg = c.black, bg = c.baby_pink },
    f_sl_noice_command = { fg = c.white, bg = t and "none" or c.bg_statusline },
    f_sl_noice_mode = { fg = c.yellow, bg = t and "none" or c.bg_statusline },
    f_sl_pos = { fg = c.black, bg = c.blue },
    f_sl_readonly = { fg = c.orange, bg = t and "none" or c.bg_statusline },
    f_sl_text = { fg = c.white, bg = t and "none" or c.bg_statusline },
    f_sl_text_command = { fg = c.vibrant_green, bg = mode_bg, bold = true },
    f_sl_text_confirm = { fg = c.teal, bg = mode_bg, bold = true },
    f_sl_text_insert = { fg = c.darker_purple, bg = mode_bg, bold = true },
    f_sl_text_normal = { fg = c.nord_blue, bg = mode_bg, bold = true },
    f_sl_text_nterminal = { fg = c.yellow, bg = mode_bg, bold = true },
    f_sl_text_replace = { fg = c.orange, bg = mode_bg, bold = true },
    f_sl_text_select = { fg = c.blue, bg = mode_bg, bold = true },
    f_sl_text_terminal = { fg = c.green, bg = mode_bg, bold = true },
    f_sl_text_visual = { fg = c.cyan, bg = mode_bg },
    f_sl_username = { fg = c.black, bg = c.cyan },
  }
  return hlgroup_map
end

return gen_hlgroup_map
