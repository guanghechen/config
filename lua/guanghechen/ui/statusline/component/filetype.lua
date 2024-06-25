---@type boolean
local transparency = fml.context.theme.transparency:get_snapshot()

--- @class guanghechen.ui.statusline.component.filetype
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
  local icon = fml.fn.calc_fileicon(filepath) .. " "
  local text = " " .. icon .. filetype .. " "
  return color_text .. text
end

return M
