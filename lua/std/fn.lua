local nvim_tools = require("nvim_tools")

---@class std.fn
local M = {}

---@param value                         unknown
---@return boolean
function M.boolean(value)
  return not not value
end

---@param ...                           any[]
---@return boolean
---@diagnostic disable-next-line: unused-vararg
function M.falsy(...)
  return false
end

---@param ...                           any[]
---@return boolean
---@diagnostic disable-next-line: unused-vararg
function M.truthy(...)
  return true
end

---@param value                         any
---@return any
function M.identity(value)
  return value
end

---@param ...                           any[]
---@return any
function M.noop(...) end

----------------------------------------------------------------------------------------------------

---@param text                          string
---@return string
function M.md5(text)
  return nvim_tools.md5(text)
end

---@return integer
function M.now()
  return nvim_tools.now()
end

---@return string
function M.uuid()
  return nvim_tools.uuid()
end

----------------------------------------------------------------------------------------------------

---@param left                          any
---@param right                         any
---@return boolean
function M.equals_deep(left, right)
  if left == right then
    return true
  end

  if type(left) ~= "table" or type(right) ~= "table" then
    return false
  end

  if #left ~= #right then
    return false
  end

  for i = 0, #left, 1 do
    if not M.equals_deep(left[i], right[i]) then
      return false
    end
  end

  for key, val in pairs(left) do
    if not M.equals_deep(val, right[key]) then
      return false
    end
  end

  for key, val in pairs(right) do
    if not M.equals_deep(val, left[key]) then
      return false
    end
  end

  return true
end

---@param left                          any
---@param right                         any
---@return boolean
function M.equals_shallow(left, right)
  return left == right
end

---@param left                          any[]
---@param right                         any[]
---@param deep                          ?boolean
---@return boolean
function M.equals_list(left, right, deep)
  if left == right then
    return true
  end

  if #left ~= #right then
    return false
  end

  local N = #left ---@type integer
  if not deep then
    for i = 1, N, 1 do
      if left[i] ~= right[i] then
        return false
      end
    end
    return true
  end

  local equals = M.equals_deep
  for i = 1, N, 1 do
    if not equals(left[i], right[i]) then
      return false
    end
  end
  return true
end

----------------------------------------------------------------------------------------------------

---@param current                       integer  current index
---@param step                          integer  moving step
---@param total                         integer  total index
---@return integer
function M.navigate_circular(current, step, total)
  local candidate = (current + step - 1) % total

  while candidate < 0 do
    candidate = candidate + total
  end

  while candidate >= total do
    candidate = candidate - total
  end

  return candidate + 1
end

---@param current                       integer  current index
---@param step                          integer  moving step
---@param total                         integer  total index.
---@return integer
function M.navigate_limit(current, step, total)
  local candidate = current + step

  if candidate < 1 then
    return 1
  end

  if candidate > total then
    return total
  end

  return candidate
end

----------------------------------------------------------------------------------------------------

---@param observables                   std.collection.IObservable[]
---@param callback                      fun(): nil
---@param ignore_initial                ?boolean
---@return std.collection.IUnsubscribable
function M.observe(observables, callback, ignore_initial)
  local unsubscribables = {} ---@type std.collection.IUnsubscribable[]
  for _, observable in ipairs(observables) do
    local subscriber = std.Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    local unsubscribable = observable:subscribe(subscriber, ignore_initial)
    unsubscribables[#unsubscribables + 1] = unsubscribable
  end

  local unsubscribed = false ---@type boolean

  ---@type std.collection.IUnsubscribable
  local unsubscribe = {
    unsubscribe = function()
      if unsubscribed then
        return
      end
      unsubscribed = true

      local batcher = std.BatchHandler.new()
      for _, unsubscribable in ipairs(unsubscribables) do
        batcher:run(unsubscribable.unsubscribe, unsubscribable)
      end
      batcher:summary("unsubscribable observers.")
    end,
  }
  return unsubscribe
end

----------------------------------------------------------------------------------------------------

---@return string[]
function M.spinner_chars()
  return {
    "⡀",
    "⠄",
    "⠂",
    "⠁",
    "⠈",
    "⠐",
    "⠠",
    "⢀",
    "⣀",
    "⢄",
    "⢂",
    "⢁",
    "⢈",
    "⢐",
    "⢠",
    "⣠",
    "⢤",
    "⢢",
    "⢡",
    "⢨",
    "⢰",
    "⣰",
    "⢴",
    "⢲",
    "⢱",
    "⢸",
    "⣸",
    "⢼",
    "⢺",
    "⢹",
    "⣹",
    "⢽",
    "⢻",
    "⣻",
    "⢿",
    "⣿",
  }
end

local spinners = M.spinner_chars() ---@type string[]
-- local spinners = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" } ---@type string[]
-- local spinners = { "", "", "", "󰪞", "󰪟", "󰪠", "󰪢", "󰪣", "󰪤", "󰪥" } ---@type string[]

---@return string
function M.spinner()
  local index = math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinners + 1 ---@type integer
  return spinners[index]
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

----------------------------------------------------------------------------------------------------

local BUFNR_DETECT_FILETYPE = -1 ---@type integer

---@param filename                      string
---@return string|nil
function M.detect_filetype(filename)
  if BUFNR_DETECT_FILETYPE < 1 or not vim.api.nvim_buf_is_valid(BUFNR_DETECT_FILETYPE) then
    BUFNR_DETECT_FILETYPE = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(BUFNR_DETECT_FILETYPE, "guanghechen://detect-filetype/" .. BUFNR_DETECT_FILETYPE)
  end
  return vim.filetype.match({ filename = filename, buf = BUFNR_DETECT_FILETYPE })
end

----------------------------------------------------------------------------------------------------

return M
