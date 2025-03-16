---@class eve.builtin.fn
local M = {}

---@param timestamp                     integer
---@return string
function M.time_ago(timestamp)
  local current_time = os.time()
  local diff = current_time - timestamp

  local seconds_in_minute = 60
  local seconds_in_hour = 3600
  local seconds_in_day = 86400
  local seconds_in_month = 2592000 -- Approximation
  local seconds_in_year = 31536000 -- Approximation

  if diff < seconds_in_minute then
    return string.format("%d seconds ago", diff)
  elseif diff < seconds_in_hour then
    return string.format("%d minutes ago", math.floor(diff / seconds_in_minute))
  elseif diff < seconds_in_day then
    return string.format("%d hours ago", math.floor(diff / seconds_in_hour))
  elseif diff < seconds_in_month then
    return string.format("%d days ago", math.floor(diff / seconds_in_day))
  elseif diff < seconds_in_year then
    return string.format("%d months ago", math.floor(diff / seconds_in_month))
  else
    return string.format("%d years ago", math.floor(diff / seconds_in_year))
  end
end

----------------------------------------------------------------------------------------------------

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
