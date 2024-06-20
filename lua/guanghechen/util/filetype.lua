---@class guanghechen.util.filetype
local M = {}

function M.calc_fileicon(p)
  local icon = "󰈚"
  local icon_highlight = nil
  local name = (p == "" and "Empty ") or p:match("([^/\\]+)[/\\]*$")

  if name ~= "Empty " then
    local devicons_present, devicons = pcall(require, "nvim-web-devicons")

    if devicons_present then
      local ft_icon, fticon_highlight = devicons.get_icon(name)
      icon = (ft_icon ~= nil and ft_icon) or icon
      icon_highlight = fticon_highlight
    end
  end

  return icon, icon_highlight
end

return M
