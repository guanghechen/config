---@class eve.constant.hlgroup.common.modes_map
local modes_map = {
  ["n"] = { "normal", "NORMAL" },
  ["no"] = { "normal", "NORMAL (no)" },
  ["nov"] = { "normal", "NORMAL (nov)" },
  ["noV"] = { "normal", "NORMAL (noV)" },
  ["noCTRL-V"] = { "normal", "NORMAL" },
  ["niI"] = { "normal", "NORMAL i" },
  ["niR"] = { "normal", "NORMAL r" },
  ["niV"] = { "normal", "NORMAL v" },
  ["nt"] = { "nterminal", "NTERMINAL" },
  ["ntT"] = { "nterminal", "NTERMINAL (ntT)" },
  ["v"] = { "visual", "VISUAL" },
  ["vs"] = { "visual", "V-CHAR (Ctrl O)" },
  ["V"] = { "visual", "V-LINE" },
  ["Vs"] = { "visual", "V-LINE" },
  [""] = { "visual", "V-BLOCK" },
  ["i"] = { "insert", "INSERT" },
  ["ic"] = { "insert", "INSERT (completion)" },
  ["ix"] = { "insert", "INSERT completion" },
  ["t"] = { "terminal", "TERMINAL" },
  ["R"] = { "replace", "REPLACE" },
  ["Rc"] = { "replace", "REPLACE (Rc)" },
  ["Rx"] = { "replace", "REPLACEa (Rx)" },
  ["Rv"] = { "replace", "V-REPLACE" },
  ["Rvc"] = { "replace", "V-REPLACE (Rvc)" },
  ["Rvx"] = { "replace", "V-REPLACE (Rvx)" },
  ["s"] = { "select", "SELECT" },
  ["S"] = { "select", "S-LINE" },
  [""] = { "select", "S-BLOCK" },
  ["c"] = { "command", "COMMAND" },
  ["cv"] = { "command", "COMMAND" },
  ["ce"] = { "command", "COMMAND" },
  ["r"] = { "confirm", "PROMPT" },
  ["rm"] = { "confirm", "MORE" },
  ["r?"] = { "confirm", "CONFIRM" },
  ["x"] = { "confirm", "CONFIRM" },
  ["!"] = { "terminal", "SHELL" },
}

---@class eve.constant.hlgroup.common
local M = {}

---@return string
---@return string
function M.resolve_mode()
  local mode = vim.api.nvim_get_mode().mode ---@type string
  local m = modes_map[mode]
  return m[1], m[2]
end

---@param context                       eve.t.theme.IContext
---@return table<string, eve.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local c = context.scheme.palette ---@type eve.t.theme.IPalette
  local t = context.transparency ---@type boolean
  local bg_main = t and c.none or c.bg0 ---@type string
  local bg_pos = t and c.bg0 or c.bg2 ---@type string

  local mc = {
    command = c.green,
    confirm = c.brightAqua,
    insert = c.purple,
    normal = c.aqua,
    nterminal = c.yellow,
    replace = c.brightYellow,
    select = c.orange,
    terminal = c.green,
    visual = c.orange,
  }

  ---@type table<string, eve.t.theme.IHlgroup>
  local hlgroup_map = {
    -- stylua: ignore start
    m_fill_command            = { fg = c.bg0,        bg = mc.command,   },
    m_fill_confirm            = { fg = c.bg0,        bg = mc.confirm,   },
    m_fill_insert             = { fg = c.bg0,        bg = mc.insert,    },
    m_fill_normal             = { fg = c.bg0,        bg = mc.normal,    },
    m_fill_nterminal          = { fg = c.bg0,        bg = mc.nterminal, },
    m_fill_replace            = { fg = c.bg0,        bg = mc.replace,   },
    m_fill_select             = { fg = c.bg0,        bg = mc.select,    },
    m_fill_terminal           = { fg = c.bg0,        bg = mc.terminal,  },
    m_fill_visual             = { fg = c.bg0,        bg = mc.visual,    },
    m_fill_b_command          = { fg = c.bg0,        bg = mc.command,   bold = true },
    m_fill_b_confirm          = { fg = c.bg0,        bg = mc.confirm,   bold = true },
    m_fill_b_insert           = { fg = c.bg0,        bg = mc.insert,    bold = true },
    m_fill_b_normal           = { fg = c.bg0,        bg = mc.normal,    bold = true },
    m_fill_b_nterminal        = { fg = c.bg0,        bg = mc.nterminal, bold = true },
    m_fill_b_replace          = { fg = c.bg0,        bg = mc.replace,   bold = true },
    m_fill_b_select           = { fg = c.bg0,        bg = mc.select,    bold = true },
    m_fill_b_terminal         = { fg = c.bg0,        bg = mc.terminal,  bold = true },
    m_fill_b_visual           = { fg = c.bg0,        bg = mc.visual,    bold = true },
    m_fill_bi_command         = { fg = c.bg0,        bg = mc.command,   bold = true, italic = true },
    m_fill_bi_confirm         = { fg = c.bg0,        bg = mc.confirm,   bold = true, italic = true },
    m_fill_bi_insert          = { fg = c.bg0,        bg = mc.insert,    bold = true, italic = true },
    m_fill_bi_normal          = { fg = c.bg0,        bg = mc.normal,    bold = true, italic = true },
    m_fill_bi_nterminal       = { fg = c.bg0,        bg = mc.nterminal, bold = true, italic = true },
    m_fill_bi_replace         = { fg = c.bg0,        bg = mc.replace,   bold = true, italic = true },
    m_fill_bi_select          = { fg = c.bg0,        bg = mc.select,    bold = true, italic = true },
    m_fill_bi_terminal        = { fg = c.bg0,        bg = mc.terminal,  bold = true, italic = true },
    m_fill_bi_visual          = { fg = c.bg0,        bg = mc.visual,    bold = true, italic = true },
    m_fill_i_command          = { fg = c.bg0,        bg = mc.command,   italic = true },
    m_fill_i_confirm          = { fg = c.bg0,        bg = mc.confirm,   italic = true },
    m_fill_i_insert           = { fg = c.bg0,        bg = mc.insert,    italic = true },
    m_fill_i_normal           = { fg = c.bg0,        bg = mc.normal,    italic = true },
    m_fill_i_nterminal        = { fg = c.bg0,        bg = mc.nterminal, italic = true },
    m_fill_i_replace          = { fg = c.bg0,        bg = mc.replace,   italic = true },
    m_fill_i_select           = { fg = c.bg0,        bg = mc.select,    italic = true },
    m_fill_i_terminal         = { fg = c.bg0,        bg = mc.terminal,  italic = true },
    m_fill_i_visual           = { fg = c.bg0,        bg = mc.visual,    italic = true },
    m_stroke_command          = { fg = mc.command,   bg = bg_main },
    m_stroke_confirm          = { fg = mc.confirm,   bg = bg_main },
    m_stroke_insert           = { fg = mc.insert,    bg = bg_main },
    m_stroke_normal           = { fg = mc.normal,    bg = bg_main },
    m_stroke_nterminal        = { fg = mc.nterminal, bg = bg_main },
    m_stroke_replace          = { fg = mc.replace,   bg = bg_main },
    m_stroke_select           = { fg = mc.select,    bg = bg_main },
    m_stroke_terminal         = { fg = mc.terminal,  bg = bg_main },
    m_stroke_visual           = { fg = mc.visual,    bg = bg_main },
    m_stroke_b_command        = { fg = mc.command,   bg = bg_main, bold = true },
    m_stroke_b_confirm        = { fg = mc.confirm,   bg = bg_main, bold = true },
    m_stroke_b_insert         = { fg = mc.insert,    bg = bg_main, bold = true },
    m_stroke_b_normal         = { fg = mc.normal,    bg = bg_main, bold = true },
    m_stroke_b_nterminal      = { fg = mc.nterminal, bg = bg_main, bold = true },
    m_stroke_b_replace        = { fg = mc.replace,   bg = bg_main, bold = true },
    m_stroke_b_select         = { fg = mc.select,    bg = bg_main, bold = true },
    m_stroke_b_terminal       = { fg = mc.terminal,  bg = bg_main, bold = true },
    m_stroke_b_visual         = { fg = mc.visual,    bg = bg_main, bold = true },
    m_stroke_bi_command       = { fg = mc.command,   bg = bg_main, bold = true, italic = true },
    m_stroke_bi_confirm       = { fg = mc.confirm,   bg = bg_main, bold = true, italic = true },
    m_stroke_bi_insert        = { fg = mc.insert,    bg = bg_main, bold = true, italic = true },
    m_stroke_bi_normal        = { fg = mc.normal,    bg = bg_main, bold = true, italic = true },
    m_stroke_bi_nterminal     = { fg = mc.nterminal, bg = bg_main, bold = true, italic = true },
    m_stroke_bi_replace       = { fg = mc.replace,   bg = bg_main, bold = true, italic = true },
    m_stroke_bi_select        = { fg = mc.select,    bg = bg_main, bold = true, italic = true },
    m_stroke_bi_terminal      = { fg = mc.terminal,  bg = bg_main, bold = true, italic = true },
    m_stroke_bi_visual        = { fg = mc.visual,    bg = bg_main, bold = true, italic = true },
    m_stroke_i_command        = { fg = mc.command,   bg = bg_main, italic = true },
    m_stroke_i_confirm        = { fg = mc.confirm,   bg = bg_main, italic = true },
    m_stroke_i_insert         = { fg = mc.insert,    bg = bg_main, italic = true },
    m_stroke_i_normal         = { fg = mc.normal,    bg = bg_main, italic = true },
    m_stroke_i_nterminal      = { fg = mc.nterminal, bg = bg_main, italic = true },
    m_stroke_i_replace        = { fg = mc.replace,   bg = bg_main, italic = true },
    m_stroke_i_select         = { fg = mc.select,    bg = bg_main, italic = true },
    m_stroke_i_terminal       = { fg = mc.terminal,  bg = bg_main, italic = true },
    m_stroke_i_visual         = { fg = mc.visual,    bg = bg_main, italic = true },
    m_pos_stroke_command      = { fg = mc.command,   bg = bg_pos,  bold = true },
    m_pos_stroke_confirm      = { fg = mc.confirm,   bg = bg_pos,  bold = true },
    m_pos_stroke_insert       = { fg = mc.insert,    bg = bg_pos,  bold = true },
    m_pos_stroke_normal       = { fg = mc.normal,    bg = bg_pos,  bold = true },
    m_pos_stroke_nterminal    = { fg = mc.nterminal, bg = bg_pos,  bold = true },
    m_pos_stroke_replace      = { fg = mc.replace,   bg = bg_pos,  bold = true },
    m_pos_stroke_select       = { fg = mc.select,    bg = bg_pos,  bold = true },
    m_pos_stroke_terminal     = { fg = mc.terminal,  bg = bg_pos,  bold = true },
    m_pos_stroke_visual       = { fg = mc.visual,    bg = bg_pos,  bold = true },

    m_fill      = { link = "m_fill_normal" },
    m_fill_b    = { link = "m_fill_b_normal" },
    m_fill_bi   = { link = "m_fill_bi_normal" },
    m_fill_i    = { link = "m_fill_i_normal" },
    m_stroke    = { link = "m_stroke_normal" },
    m_stroke_b  = { link = "m_stroke_b_normal" },
    m_stroke_bi = { link = "m_stroke_bi_normal" },
    m_stroke_i  = { link = "m_stroke_i_normal" },
    m_pos_sep   = { link = "m_pos_sep_normal" },
    -- stylua: ignore end
  }

  return hlgroup_map
end

---@return nil
function M.on_mode_changed()
  local mode = M.resolve_mode() ---@type string
  -- stylua: ignore start
  vim.api.nvim_set_hl(0, "m_fill",      { link = "m_fill_"      .. mode })
  vim.api.nvim_set_hl(0, "m_fill_b",    { link = "m_fill_b_"    .. mode })
  vim.api.nvim_set_hl(0, "m_fill_bi",   { link = "m_fill_bi_"   .. mode })
  vim.api.nvim_set_hl(0, "m_fill_i",    { link = "m_fill_i_"    .. mode })
  vim.api.nvim_set_hl(0, "m_stroke",    { link = "m_stroke_"    .. mode })
  vim.api.nvim_set_hl(0, "m_stroke_b",  { link = "m_stroke_b_"  .. mode })
  vim.api.nvim_set_hl(0, "m_stroke_bi", { link = "m_stroke_bi_" .. mode })
  vim.api.nvim_set_hl(0, "m_stroke_i",  { link = "m_stroke_i_"  .. mode })
  vim.api.nvim_set_hl(0, "m_pos_stoke", { link = "m_pos_stoke_" .. mode })
  -- stylua: ignore end
end

return M
