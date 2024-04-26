local ui = require("ghc.setting.ui")

---@class ghc.ui.statusline.component.mode
local M = {
  name = "ghc_statusline_mode",
}

---@param name? string
---@param fg? string|nil
---@param bg? string|nil
function M.gen_color_withmodes(name, fg, bg)
  local result = {}

  local function gen_color_withmode(mode, color)
    result[name .. "_" .. mode] = {
      fg = fg or color,
      bg = bg or color,
    }
  end

  gen_color_withmode("NORMAL", "nord_blue")
  gen_color_withmode("VISUAL", "cyan")
  gen_color_withmode("INSERT", "dark_purple")
  gen_color_withmode("TERMINAL", "green")
  gen_color_withmode("NTERMINAL", "yellow")
  gen_color_withmode("REPLACE", "orange")
  gen_color_withmode("CONFIRM", "teal")
  gen_color_withmode("COMMAND", "green")
  gen_color_withmode("SELECT", "blue")

  return result
end

M.color = vim.tbl_deep_extend(
  "force",
  M.gen_color_withmodes("icon", "babypink", nil),
  M.gen_color_withmodes("separator", nil, "black"),
  M.gen_color_withmodes("separator_rightest", nil, "black"),
  M.gen_color_withmodes("text", "black", nil)
)

function M.condition()
  return require("nvchad.stl.utils").is_activewin()
end

---@param opts { is_rightest: boolean }
function M.renderer_left(opts)
  local is_rightest = opts.is_rightest
  local m = vim.api.nvim_get_mode().mode
  local modes = require("nvchad.stl.utils").modes
  local mode_name = modes[m][2]

  local color_separator = "%#" .. M.name .. (is_rightest and "_separator_rightest" or "_separator") .. "_" .. mode_name .. "#"
  local color_icon = "%#" .. M.name .. "_icon" .. "_" .. mode_name .. "#"
  local color_text = "%#" .. M.name .. "_text" .. "_" .. mode_name .. "#"

  local separator = ui.statusline.symbol.separator.right
  local icon = ui.statusline.symbol.separator.right .. " "
  local text = " " .. mode_name .. " "
  return color_icon .. icon .. color_text .. text .. color_separator .. separator
end

return M
