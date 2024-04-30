---@class guanghechen.timer.Timer
local Timer = {}

---@param o table|nil
---@param name string
function Timer:new(o, name)
  o = o or {}
  setmetatable(o, self)

  self._name = name
  self._timer = vim.loop.new_timer()

  return o
end

---@param timeout   number millionsecondsggj
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
