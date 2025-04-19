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
  local cs = eve.std.color
  local theme = context.scheme.theme ---@type eve.e.Theme
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
    m_text_command      = { fg = c.bg0,         bg = mc.command,   bold = true },
    m_text_confirm      = { fg = c.bg0,         bg = mc.confirm,   bold = true },
    m_text_insert       = { fg = c.bg0,         bg = mc.insert,    bold = true },
    m_text_normal       = { fg = c.bg0,         bg = mc.normal,    bold = true },
    m_text_nterminal    = { fg = c.bg0,         bg = mc.nterminal, bold = true },
    m_text_replace      = { fg = c.bg0,         bg = mc.replace,   bold = true },
    m_text_select       = { fg = c.bg0,         bg = mc.select,    bold = true },
    m_text_terminal     = { fg = c.bg0,         bg = mc.terminal,  bold = true },
    m_text_visual       = { fg = c.bg0,         bg = mc.visual,    bold = true },
    m_sep_command       = { fg = mc.command,    bg = bg_main,      bold = true },
    m_sep_confirm       = { fg = mc.confirm,    bg = bg_main,      bold = true },
    m_sep_insert        = { fg = mc.insert,     bg = bg_main,      bold = true },
    m_sep_normal        = { fg = mc.normal,     bg = bg_main,      bold = true },
    m_sep_nterminal     = { fg = mc.nterminal,  bg = bg_main,      bold = true },
    m_sep_replace       = { fg = mc.replace,    bg = bg_main,      bold = true },
    m_sep_select        = { fg = mc.select,     bg = bg_main,      bold = true },
    m_sep_terminal      = { fg = mc.terminal,   bg = bg_main,      bold = true },
    m_sep_visual        = { fg = mc.visual,     bg = bg_main,      bold = true },
    m_pos_sep_command   = { fg = mc.command,    bg = bg_pos,       bold = true },
    m_pos_sep_confirm   = { fg = mc.confirm,    bg = bg_pos,       bold = true },
    m_pos_sep_insert    = { fg = mc.insert,     bg = bg_pos,       bold = true },
    m_pos_sep_normal    = { fg = mc.normal,     bg = bg_pos,       bold = true },
    m_pos_sep_nterminal = { fg = mc.nterminal,  bg = bg_pos,       bold = true },
    m_pos_sep_replace   = { fg = mc.replace,    bg = bg_pos,       bold = true },
    m_pos_sep_select    = { fg = mc.select,     bg = bg_pos,       bold = true },
    m_pos_sep_terminal  = { fg = mc.terminal,   bg = bg_pos,       bold = true },
    m_pos_sep_visual    = { fg = mc.visual,     bg = bg_pos,       bold = true },

    -- stylua: ignore end

    m_text = { link = "m_text_normal" },
    m_sep = { link = "m_sep_normal" },
    m_pos_sep = { link = "m_pos_sep_normal" },
  }

  if theme == "gruvbox" then
  elseif theme == "one_half" then
    hlgroup_map.Comment.fg = cs.change_hex_lightness(c.bg4, 20)
    hlgroup_map.CursorLine.bg = c.bg2
    hlgroup_map.CursorLineNr.bg = c.bg2
    hlgroup_map.Identifier.fg = c.red
  end

  return hlgroup_map
end

---@return nil
function M.on_mode_changed()
  local mode = M.resolve_mode() ---@type string
  vim.api.nvim_set_hl(0, "m_text", { link = "m_text_" .. mode })
  vim.api.nvim_set_hl(0, "m_sep", { link = "m_sep_" .. mode })
  vim.api.nvim_set_hl(0, "m_pos_sep", { link = "m_pos_sep_" .. mode })
end

return M
