local icons = require("ghc.core.setting.icons")
local ui = require("ghc.core.setting.ui")

local fileformat_icon_map = {
  dos = icons.os.dos,
  mac = icons.os.mac,
  unix = icons.os.unix,
}

local fileformat_text_map = {
  dos = "CRLF",
  mac = "CR",
  unix = "LF",
}

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
    fg = "white",
    bg = ui.transparency and "none" or "statusline_bg",
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

  local icon_fileformat = fileformat_icon_map[vim.bo.fileformat] or icons.os.unknown
  local text_fileformat = fileformat_text_map[vim.bo.fileformat] or "UNKNOWN"

  local icon_tab = icons.ui.Tab .. " "
  local text_tab = vim.api.nvim_get_option_value("shiftwidth", { scope = "local" })

  local separator = ui.statusline.symbol.separator.left
  local icon = icon_fileformat .. " "
  local text = " " .. text_fileformat .. " " .. icon_tab .. text_tab .. " "
  return color_separator .. separator .. color_icon .. icon .. color_text .. text
end

return M
