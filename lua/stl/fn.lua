---@class stl.fn
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

---@param observables                   stl.c.Observable[]
---@param callback                      fun(): nil
---@param ignore_initial                ?boolean
---@return stl.c.IUnsubscribable
function M.observe(observables, callback, ignore_initial)
  local unsubscribables = {} ---@type stl.c.IUnsubscribable[]
  for _, observable in ipairs(observables) do
    local subscriber = stl.c.Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    local unsubscribable = observable:subscribe(subscriber, ignore_initial)
    unsubscribables[#unsubscribables + 1] = unsubscribable
  end

  local unsubscribed = false ---@type boolean

  ---@type stl.c.IUnsubscribable
  local unsubscribe = {
    unsubscribe = function()
      if unsubscribed then
        return
      end
      unsubscribed = true

      local batcher = stl.c.BatchHandler.new()
      for _, unsubscribable in ipairs(unsubscribables) do
        batcher:run(unsubscribable.unsubscribe, unsubscribable)
      end
      batcher:summary("unsubscribable observers.")
    end,
  }
  return unsubscribe
end

return M
