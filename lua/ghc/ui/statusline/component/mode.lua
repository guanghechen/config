local ui = require("ghc.core.setting.ui")

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

M.color = vim.tbl_deep_extend(
  "force",
  M.gen_color_withmodes("icon", "baby_pink", nil, false),
  M.gen_color_withmodes("separator", nil, "grey", false),
  M.gen_color_withmodes("separator_rightest", nil, "lightbg", false),
  M.gen_color_withmodes("text", "black", nil, true),
  {
    separator_extend = {
      fg = "grey",
      bg = "lightbg",
    },
    separator_extend_rightest = {
      fg = "grey",
      bg = "grey",
    },
  }
)

function M.condition()
  return require("nvchad.stl.utils").is_activewin()
end

---@param opts { is_rightest: boolean }
function M.renderer_left(opts)
  local is_rightest = opts.is_rightest
  local m = vim.api.nvim_get_mode().mode
  local mode_name = M.modes_map[m][2]
  local mode_display_name = M.modes_map[m][1]

  local color_icon = "%#" .. M.name .. "_icon" .. "_" .. mode_name .. "#"
  local color_text = "%#" .. M.name .. "_text" .. "_" .. mode_name .. "#"
  local color_separator = "%#" .. M.name .. (is_rightest and "_separator_rightest" or "_separator") .. "_" .. mode_name .. "#"
  local color_separator_extend = "%#" .. M.name .. (is_rightest and "_separator_extend_rightest" or "_separator_extend") .. "#"

  local icon = ui.statusline.symbol.separator.right .. " "
  local text = mode_display_name .. " "
  local separator = is_rightest and "" or ui.statusline.symbol.separator.right
  local separator_extend = is_rightest and " " or ui.statusline.symbol.separator.right
  return color_icon .. icon .. color_text .. text .. color_separator .. separator .. color_separator_extend .. separator_extend
end

return M
