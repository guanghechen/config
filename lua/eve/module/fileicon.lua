---@class eve.module.fileicon
local M = {}

---@param filename                      string
---@return string
---@return string
function M.calc_fileicon(filename)
  if #filename == 0 then
    return eve.icon.filetype.Unknown, "MiniIconsRed"
  end

  if filename:sub(#filename, #filename) == "/" then
    return eve.icon.filetype.Folder, "MiniIconsBlue"
  end

  local name = (not filename or filename == "") and eve.setting.BUF_UNTITLED or filename
  local ok, mini_icons = pcall(require, "mini.icons")
  if ok and name ~= eve.setting.BUF_UNTITLED then
    local icon, icon_hl, is_default = mini_icons.get("file", filename)
    if not is_default then
      return icon, icon_hl
    end
  end
  return eve.icon.filetype.Unknown, "MiniIconsRed"
end

return M
