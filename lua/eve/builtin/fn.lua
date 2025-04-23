---@class eve.builtin.fn
local M = {}

---@generic T
---@param fn                            T
---@param delay                         ?integer
---@return T
function M.debounce(fn, delay)
  local timer = assert(vim.uv.new_timer()) ---@type uv.uv_timer_t
  local duration = delay or 20 ---@type integer
  return function()
    timer:start(duration, 0, vim.schedule_wrap(fn))
  end
end

local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } ---@type string[]
-- local spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" } ---@type string[]

---@return string
function M.spinner()
  local index = math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinners + 1 ---@type integer
  return spinners[index]
end

----------------------------------------------------------------------------------------------------

---@param filename                      string
---@return string
---@return string
function M.fileicon(filename)
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
