local context_config = require("ghc.core.context.config")
local icons = require("ghc.core.setting.icons")

---@type boolean
local transparency = context_config.transparency:get_snapshot()

local fileformat_text_map = {
  dos = "CRLF",
  mac = "CR",
  unix = "LF",
}

--- @class ghc.ui.statusline.component.fileformat
local M = {
  name = "ghc_statusline_os",
  color = {
    text = {
      fg = "white",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  return vim.o.columns > 100
end

function M.renderer()
  local color_text = "%#" .. M.name .. "_text#"

  ---@diagnostic disable-next-line: undefined-field
  local text_encoding = vim.opt.fileencoding:get()

  local text_fileformat = fileformat_text_map[vim.bo.fileformat] or "UNKNOWN"

  local icon_tab = icons.ui.Tab .. " "
  local text_tab = vim.api.nvim_get_option_value("shiftwidth", { scope = "local" })

  local text = " " .. text_encoding .. " " .. text_fileformat .. " " .. icon_tab .. text_tab .. " "
  return color_text .. text
end

return M
