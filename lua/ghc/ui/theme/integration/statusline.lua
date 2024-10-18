---@param params                        ghc.types.ui.theme.IGenHlgroupMapParams
---@return ghc.ui.theme.integration.statusline.hlgroups
local function gen_hlgroup_map(params)
  local mode = params.scheme.mode ---@type fml.enums.theme.Mode
  local c = params.scheme.palette ---@type fml.types.ui.theme.IPalette
  local t = params.transparency ---@type boolean
  local bg_statusline = c.bg2
  local mode_bg = t and "none" or c.bg3 ---@type string

  ---@class ghc.ui.theme.integration.statusline.hlgroups : table<string, fml.types.ui.theme.IHlgroup>
  local hlgroup_map = {
    f_sl_bg = { fg = t and "none" or bg_statusline, bg = t and "none" or bg_statusline },
    f_sl_copilot_InProgress = { fg = c.cyan, bg = t and "none" or bg_statusline },
    f_sl_copilot_Inactive = { fg = c.red, bg = t and "none" or bg_statusline },
    f_sl_copilot_Normal = { fg = c.blue, bg = t and "none" or bg_statusline },
    f_sl_copilot_Warning = { fg = c.yellow, bg = t and "none" or bg_statusline },
    f_sl_diagnostics_error = { fg = c.red, bg = t and "none" or bg_statusline },
    f_sl_diagnostics_hint = { fg = c.purple, bg = t and "none" or bg_statusline },
    f_sl_diagnostics_info = { fg = c.green, bg = t and "none" or bg_statusline },
    f_sl_diagnostics_warn = { fg = c.yellow, bg = t and "none" or bg_statusline },
    f_sl_flag = { fg = c.fg0, bg = t and "none" or c.bg3 },
    f_sl_flag_enabled = { fg = c.black, bg = c.bg_blue },
    f_sl_flag_scope = { fg = c.black, bg = c.pink },
    f_sl_noice_command = { fg = c.fg0, bg = t and "none" or bg_statusline },
    f_sl_noice_mode = { fg = c.yellow, bg = t and "none" or bg_statusline },
    f_sl_pos = { fg = mode == "darken" and c.black or c.white, bg = c.bg_blue },
    f_sl_readonly = { fg = c.dark_yellow, bg = t and "none" or bg_statusline },
    f_sl_text = { fg = c.fg0, bg = t and "none" or bg_statusline },
    f_sl_text_command = { fg = c.green, bg = mode_bg, bold = true },
    f_sl_text_confirm = { fg = c.dark_cyan, bg = mode_bg, bold = true },
    f_sl_text_insert = { fg = c.dark_purple, bg = mode_bg, bold = true },
    f_sl_text_normal = { fg = c.bg_cyan, bg = mode_bg, bold = true },
    f_sl_text_nterminal = { fg = c.yellow, bg = mode_bg, bold = true },
    f_sl_text_replace = { fg = c.yellow, bg = mode_bg, bold = true },
    f_sl_text_select = { fg = c.blue, bg = mode_bg, bold = true },
    f_sl_text_terminal = { fg = c.green, bg = mode_bg, bold = true },
    f_sl_text_visual = { fg = c.cyan, bg = mode_bg },
    f_sl_username = { fg = mode == "darken" and c.black or c.white, bg = c.bg_cyan },
  }
  return hlgroup_map
end

return gen_hlgroup_map
