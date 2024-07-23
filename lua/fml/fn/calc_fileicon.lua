local highlight = require("fml.std.highlight")
local constant = require("fml.constant")

---@type table<string, string>
local icon_hl_cache = {}

---@param filepath string
---@return string
---@return string
local function calc_fileicon(filepath)
  local name = (not filepath or filepath == "") and constant.BUF_UNTITLED or filepath:match("([^/\\]+)[/\\]*$")
  local icon = "󰈚"
  local icon_hl = "DevIconDefault"

  if name ~= constant.BUF_UNTITLED then
    local devicons_present, devicons = pcall(require, "nvim-web-devicons")
    if devicons_present then
      local fticon, fticon_hl = devicons.get_icon(name)
      icon = fticon or icon
      icon_hl = fticon_hl or icon_hl
    end
  end

  --  if icon_hl_cache[icon_hl] then
  --    icon_hl = icon_hl_cache[icon_hl]
  --  else
  --    icon_hl = highlight.make_bg_transparency(icon_hl)
  --    icon_hl_cache[icon] = icon_hl
  --  end

  return icon, icon_hl
end

return calc_fileicon
