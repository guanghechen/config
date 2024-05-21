---@class guanghechen.timer.Timer
---@field _name string
local Timer = {}
Timer.__index = Timer

---@param name string
function Timer.new(name)
  local self = setmetatable({}, Timer)

  self._name = name
  self._timer = vim.uv.new_timer()

  return self
end

---@param timeout   number millionseconds
---@param interval  number if 0 then only called once.
---@param callback  fun():nil a callback which will executed when the tiemout.
---@return nil
function Timer:start(timeout, interval, callback)
  if self._timer == nil then
    error("This timer (" .. self._name .. ") has been released!")
    return
  end
  self._timer.start(timeout, interval, vim.schedule_wrap(callback))
end

---@return nil
function Timer:stop()
  if self._timer ~= nil then
    self._timer.stop()
  end
end

---@return nil
function Timer:release()
  self._timer = nil
end

return Timer
