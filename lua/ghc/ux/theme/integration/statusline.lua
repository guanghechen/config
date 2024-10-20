---@param context                       t.ghc.ux.IThemeContext
---@return ghc.ux.theme.integration.statusline.hlgroups
local function gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type t.fml.ux.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_statusline = c.bg2
  local mode_bg = t and "none" or c.bg3 ---@type string

  ---@class ghc.ux.theme.integration.statusline.hlgroups : table<string, t.fml.ux.theme.IHlgroup>
  local hlgroup_map = {
    f_sl_bg = { fg = t and "none" or bg_statusline, bg = t and "none" or bg_statusline },
    f_sl_copilot_InProgress = { fg = c.aqua, bg = t and "none" or bg_statusline },
    f_sl_copilot_Inactive = { fg = c.red, bg = t and "none" or bg_statusline },
    f_sl_copilot_Normal = { fg = c.blue, bg = t and "none" or bg_statusline },
    f_sl_copilot_Warning = { fg = c.yellow, bg = t and "none" or bg_statusline },
    f_sl_diagnostics_error = { fg = c.red, bg = t and "none" or bg_statusline },
    f_sl_diagnostics_hint = { fg = c.purple, bg = t and "none" or bg_statusline },
    f_sl_diagnostics_info = { fg = c.green, bg = t and "none" or bg_statusline },
    f_sl_diagnostics_warn = { fg = c.yellow, bg = t and "none" or bg_statusline },
    f_sl_flag = { fg = c.fg0, bg = t and "none" or c.bg3 },
    f_sl_flag_enabled = { fg = c.bg0_s, bg = c.blue },
    f_sl_flag_scope = { fg = c.bg0_s, bg = c.orange },
    f_sl_noice_command = { fg = c.fg0, bg = t and "none" or bg_statusline },
    f_sl_noice_mode = { fg = c.yellow, bg = t and "none" or bg_statusline },
    f_sl_pos = { fg = c.bg0_s, bg = c.blue },
    f_sl_readonly = { fg = c.orange, bg = t and "none" or bg_statusline },
    f_sl_text = { fg = c.fg0, bg = t and "none" or bg_statusline },
    f_sl_text_command = { fg = c.green, bg = mode_bg, bold = true },
    f_sl_text_confirm = { fg = c.neutral_aqua, bg = mode_bg, bold = true },
    f_sl_text_insert = { fg = c.neutral_purple, bg = mode_bg, bold = true },
    f_sl_text_normal = { fg = c.aqua, bg = mode_bg, bold = true },
    f_sl_text_nterminal = { fg = c.yellow, bg = mode_bg, bold = true },
    f_sl_text_replace = { fg = c.yellow, bg = mode_bg, bold = true },
    f_sl_text_select = { fg = c.blue, bg = mode_bg, bold = true },
    f_sl_text_terminal = { fg = c.green, bg = mode_bg, bold = true },
    f_sl_text_visual = { fg = c.aqua, bg = mode_bg },
    f_sl_username = { fg = c.bg0_s, bg = c.blue },
  }
  return hlgroup_map
end

return gen_hlgroup_map
