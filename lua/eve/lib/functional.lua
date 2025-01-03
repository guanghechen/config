local setting = require("eve.constant.setting")
local EDITING_PREFIX = setting.EDITING_INPUT_PREFIX ---@type string

---@class eve.lib.functional
local M = {}

---@param ...                           any[]
---@return any
function M.noop(...) end

---@generic T
---@param elements                      T[]
---@param element                       T
---@return integer|nil
function M.find_index(elements, element)
  for i = 1, #elements, 1 do
    if elements[i] == element then
      return i
    end
  end
end

---@param text                          string
---@return string[]
function M.parse_comma_list(text)
  local result = {} ---@type string[]
  local items = vim.split(text, ",", { plain = true })
  for _, item in ipairs(items) do
    local v = item:match("^%s*(.-)%s*$")
    if #v > 0 then
      table.insert(result, v)
    end
  end
  return result
end

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

---@param text                          string
---@return boolean
function M.is_editing_text(text)
  return #text >= #EDITING_PREFIX and text:sub(1, #EDITING_PREFIX) == EDITING_PREFIX
end

---@param text                          string
---@return string
function M.unwrap_editing_prefix(text)
  return M.is_editing_text(text) and text:sub(#EDITING_PREFIX + 1) or text
end

return M
