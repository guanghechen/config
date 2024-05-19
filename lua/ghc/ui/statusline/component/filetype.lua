local context_config = require("ghc.core.context.config")
local calc_fileicon = require("ghc.core.util.filetype").calc_fileicon

---@type boolean
local transparency = context_config.transparency:get_snapshot()

--- @class ghc.ui.statusline.component.filetype
local M = {
  name = "ghc_statusline_filetype",
}

M.color = {
  text = {
    fg = "white",
    bg = transparency and "none" or "statusline_bg",
  },
}

function M.condition()
  local filetype = vim.bo.filetype
  return filetype and #filetype > 0
end

function M.renderer()
  local filetype = vim.bo.filetype
  local filepath = vim.fn.expand("%:p")
  local color_text = "%#" .. M.name .. "_text#"
  local icon = calc_fileicon(filepath) .. " "
  local text = " " .. icon .. filetype .. " "
  return color_text .. text
end

return M
