local icons = require("ghc.core.setting.icons")
local globals = require("ghc.core.setting.globals")
local ui = require("ghc.core.setting.ui")

local fileformat_text_map = {
  dos = "CRLF",
  mac = "CR",
  unix = "LF",
}

local function get_os_icon()
  if globals.is_mac then
    return icons.os.mac
  elseif globals.is_windows then
    return icons.os.dos
  elseif globals.is_linux or globals.is_wsl then
    return icons.os.unix
  else
    return icons.os.unknown
  end
end

--- @class ghc.ui.statusline.component.os
local M = {
  name = "ghc_statusline_os",
}

M.color = {
  icon = {
    fg = "black",
    bg = "cyan",
  },
  separator = {
    fg = "cyan",
    bg = "statusline_bg",
  },
  separator_leftest = {
    fg = "cyan",
    bg = ui.transparency and "none" or "statusline_bg",
  },
  text = {
    fg = "black",
    bg = "cyan",
  },
}

function M.condition()
  return vim.o.columns > 100
end

---@param opts { is_leftest: boolean }
function M.renderer_right(opts)
  local is_leftest = opts.is_leftest

  local color_separator = "%#" .. M.name .. (is_leftest and "_separator_leftest#" or "_separator#")
  local color_icon = "%#" .. M.name .. "_icon#"
  local color_text = "%#" .. M.name .. "_text#"

  ---@diagnostic disable-next-line: undefined-field
  local text_encoding = vim.opt.fileencoding:get()

  local icon_fileformat = get_os_icon()
  local text_fileformat = fileformat_text_map[vim.bo.fileformat] or "UNKNOWN"

  local icon_tab = icons.ui.Tab .. " "
  local text_tab = vim.api.nvim_get_option_value("shiftwidth", { scope = "local" })

  local separator = ui.statusline.symbol.separator.left
  local icon = icon_fileformat .. " "
  local text = text_encoding .. " " .. text_fileformat .. " " .. icon_tab .. text_tab .. " "
  return color_separator .. separator .. color_icon .. icon .. color_text .. text
end

return M
