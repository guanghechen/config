---@type boolean
local transparency = ghc.context.shared.transparency:get_snapshot()

--- @class guanghechen.ui.statusline.component.cwd
local M = {
  name = "ghc_statusline_cwd",
  color = {
    text = {
      fg = "white",
      bg = transparency and "none" or "statusline_bg",
    },
  },
}

function M.condition()
  return vim.o.columns > 85
end

function M.renderer()
  local cwd = fml.path.cwd()
  local cwd_name = (cwd:match("([^/\\]+)[/\\]*$") or cwd)
  local color_text = "%#" .. M.name .. "_text#"
  local text = " 󰉋 " .. cwd_name .. " "
  return color_text .. text
end

return M