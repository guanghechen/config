---@type boolean
local transparency = fml.context.theme.transparency:get_snapshot()

---@class ghc.ui.statusline.component.mode
local M = {
  name = "ghc_statusline_mode",
}

M.modes_map = {
  ["n"] = { "NORMAL", "normal" },
  ["no"] = { "NORMAL (no)", "normal" },
  ["nov"] = { "NORMAL (nov)", "normal" },
  ["noV"] = { "NORMAL (noV)", "normal" },
  ["noCTRL-V"] = { "NORMAL", "normal" },
  ["niI"] = { "NORMAL i", "normal" },
  ["niR"] = { "NORMAL r", "normal" },
  ["niV"] = { "NORMAL v", "normal" },
  ["nt"] = { "NTERMINAL", "nterminal" },
  ["ntT"] = { "NTERMINAL (ntT)", "nterminal" },

  ["v"] = { "VISUAL", "visual" },
  ["vs"] = { "V-CHAR (Ctrl O)", "visual" },
  ["V"] = { "V-LINE", "visual" },
  ["Vs"] = { "V-LINE", "visual" },
  [""] = { "V-BLOCK", "visual" },

  ["i"] = { "INSERT", "insert" },
  ["ic"] = { "INSERT (completion)", "insert" },
  ["ix"] = { "INSERT completion", "insert" },

  ["t"] = { "TERMINAL", "terminal" },

  ["R"] = { "REPLACE", "replace" },
  ["Rc"] = { "REPLACE (Rc)", "replace" },
  ["Rx"] = { "REPLACEa (Rx)", "replace" },
  ["Rv"] = { "V-REPLACE", "replace" },
  ["Rvc"] = { "V-REPLACE (Rvc)", "replace" },
  ["Rvx"] = { "V-REPLACE (Rvx)", "replace" },

  ["s"] = { "SELECT", "select" },
  ["S"] = { "S-LINE", "select" },
  [""] = { "S-BLOCK", "select" },
  ["c"] = { "COMMAND", "command" },
  ["cv"] = { "COMMAND", "command" },
  ["ce"] = { "COMMAND", "command" },
  ["r"] = { "PROMPT", "confirm" },
  ["rm"] = { "MORE", "confirm" },
  ["r?"] = { "CONFIRM", "confirm" },
  ["x"] = { "CONFIRM", "confirm" },
  ["!"] = { "SHELL", "terminal" },
}

---@param name? string
---@param fg? string|nil
---@param bg? string|nil
---@param bold? boolean|nil
function M.gen_color_withmodes(name, fg, bg, bold)
  local result = {}

  local function gen_color_withmode(mode, color)
    result[name .. "_" .. mode] = {
      fg = fg or color,
      bg = bg or color,
      bold = bold,
    }
  end

  gen_color_withmode("normal", "nord_blue")
  gen_color_withmode("visual", "cyan")
  gen_color_withmode("insert", "dark_purple")
  gen_color_withmode("terminal", "green")
  gen_color_withmode("nterminal", "yellow")
  gen_color_withmode("replace", "orange")
  gen_color_withmode("confirm", "teal")
  gen_color_withmode("command", "vibrant_green")
  gen_color_withmode("select", "blue")

  return result
end

M.color = vim.tbl_deep_extend("force", M.gen_color_withmodes("text", nil, transparency and "none" or "statusline_bg", true), {})

function M.condition()
  return vim.api.nvim_get_current_win() == vim.g.statusline_winid
end

function M.renderer()
  local m = vim.api.nvim_get_mode().mode
  local mode_name = M.modes_map[m][2]
  local mode_display_name = M.modes_map[m][1]

  local color_text = "%#" .. M.name .. "_text" .. "_" .. mode_name .. "#"
  local text = "  " .. mode_display_name .. " "
  return color_text .. text
end

return M
