---@type boolean
local transparency = ghc.context.shared.transparency:get_snapshot()

--- @class guanghechen.ui.statusline.component.readonly
local M = {
  name = "ghc_statusline_readonly",
  color = {
    text = {
      fg = "orange",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  local readonly = vim.api.nvim_get_option_value("readonly", { buf = 0 }) ---@type boolean
  return readonly
end

function M.renderer()
  local color_text = "%#" .. M.name .. "_text#"
  local text = " " .. fml.ui.icons.ui.Lock .. " [RO] "
  return color_text .. text
end

return M
