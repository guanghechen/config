local setting = require("eve.constant.setting")
local icons = require("eve.constant.icon")

---@class eve.module.fileicon
local M = {}

---@param filename                      string
---@return string
---@return string
function M.calc_fileicon(filename)
  if #filename == 0 then
    return icons.filetype.Unknown, "MiniIconsRed"
  end

  if filename:sub(#filename, #filename) == "/" then
    return icons.filetype.Folder, "MiniIconsBlue"
  end

  local name = (not filename or filename == "") and setting.BUF_UNTITLED or filename
  local ok, mini_icons = pcall(require, "mini.icons")
  if ok and name ~= setting.BUF_UNTITLED then
    local icon, icon_hl, is_default = mini_icons.get("file", filename)
    if not is_default then
      return icon, icon_hl
    end
  end
  return icons.filetype.Unknown, "MiniIconsRed"
end

return M
