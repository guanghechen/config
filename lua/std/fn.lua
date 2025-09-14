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

  for i = 1, #left, 1 do
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
  if total <= 0 then
    return 1
  end

  -- Convert to 0-based indexing, apply step, then normalize and convert back
  local candidate = ((current - 1 + step) % total + total) % total + 1
  return candidate
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

---@param step                          ?integer
---@return string
function M.spinner(step)
  step = step and 1e6 or (1e6 * 80) ---@type integer
  local index = math.floor(vim.uv.hrtime() / step) % #spinners + 1 ---@type integer
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

---@return nil
local function cleanup_filetype_buffer()
  if BUFNR_DETECT_FILETYPE > 0 and vim.api.nvim_buf_is_valid(BUFNR_DETECT_FILETYPE) then
    vim.api.nvim_buf_delete(BUFNR_DETECT_FILETYPE, { force = true })
    BUFNR_DETECT_FILETYPE = -1
  end
end

---@param filename                      string
---@return string|nil
function M.detect_filetype(filename)
  if BUFNR_DETECT_FILETYPE < 1 or not vim.api.nvim_buf_is_valid(BUFNR_DETECT_FILETYPE) then
    BUFNR_DETECT_FILETYPE = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(BUFNR_DETECT_FILETYPE, "guanghechen://detect-filetype/" .. BUFNR_DETECT_FILETYPE)

    -- Set up cleanup when Neovim exits
    vim.api.nvim_create_autocmd("VimLeavePre", {
      callback = cleanup_filetype_buffer,
      once = true,
    })
  end
  return vim.filetype.match({ filename = filename, buf = BUFNR_DETECT_FILETYPE })
end

----------------------------------------------------------------------------------------------------

return M
