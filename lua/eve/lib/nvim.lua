local setting = require("eve.constant.setting")

---@class eve.lib.nvim
local M = {}

---@param filename                      string
---@return string
---@return string
function M.calc_fileicon(filename)
  local name = (not filename or filename == "") and setting.BUF_UNTITLED or filename
  local icons_present, icons = pcall(require, "mini.icons")
  if icons_present and name ~= setting.BUF_UNTITLED then
    local icon, icon_hl, is_default = icons.get("file", filename)
    if not is_default then
      return icon, icon_hl
    end
  end
  return "󰈚", "MiniIconsRed"
end

return M
