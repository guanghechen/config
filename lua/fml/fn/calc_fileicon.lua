---@param filepath string
---@return string, string|nil
local function calc_fileicon(filepath)
  local icon = "󰈚"
  local icon_highlight = nil
  local name = (filepath == "" and "Empty ") or filepath:match("([^/\\]+)[/\\]*$")

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

return calc_fileicon
