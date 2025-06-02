---@class eve.builtin.fn
local M = {}

-- stylua: ignore start
local BYTE_PATHSEP    = string.byte(std.env.PATH_SEP) ---@type integer
-- stylua: ignore end

local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } ---@type string[]
-- local spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" } ---@type string[]

---@return string
function M.spinner()
  local index = math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinners + 1 ---@type integer
  return spinners[index]
end

----------------------------------------------------------------------------------------------------

---@param dirname                       string
---@return string
---@return string
function M.diricon(dirname)
  if #dirname == 0 then
    return eve.icon.filetype.Folder, "MiniIconsBlue"
  end

  if string.byte(dirname, #dirname, #dirname) == BYTE_PATHSEP then
    return eve.icon.filetype.Folder, "MiniIconsBlue"
  end

  local name = (not dirname or dirname == "") and eve.setting.BUF_UNTITLED or dirname
  local ok, mini_icons = pcall(require, "mini.icons")
  if ok and name ~= eve.setting.BUF_UNTITLED then
    local icon, icon_hl, is_default = mini_icons.get("directory", dirname)
    if not is_default then
      return icon, icon_hl
    end
  end
  return eve.icon.filetype.Folder, "MiniIconsBlue"
end

---@param filename                      string
---@return string
---@return string
function M.fileicon(filename)
  if #filename == 0 then
    return eve.icon.filetype.Unknown, "MiniIconsRed"
  end

  if string.byte(filename, #filename, #filename) == BYTE_PATHSEP then
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
