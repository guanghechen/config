---@param filepath string
---@return string, string
local function calc_fileicon(filepath)
  local name    = (not filepath or filepath == "") and " Untitled " or filepath:match("([^/\\]+)[/\\]*$")
  local icon    = "󰈚"
  local icon_hl = "DevIconDefault"

  if name ~= " Untitled " then
    local devicons_present, devicons = pcall(require, "nvim-web-devicons")
    if devicons_present then
      local fticon, fticon_hl = devicons.get_icon(name)
      icon = fticon or icon
      icon_hl = fticon_hl or icon_hl
    end
  end

  return icon, icon_hl
end

return calc_fileicon
