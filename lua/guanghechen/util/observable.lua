local Subscriber = require("guanghechen.subscriber.Subscriber")

---@class guanghechen.util.observable
local M = {}

---@param observable any
---@return boolean
function M.is_observable(observable)
  return type(observable) == "table"
    and type(observable.get_snapshot) == "function"
    and type(observable.next) == "function"
    and type(observable.subscribe) == "function"
end

---@param observables guanghechen.types.IObservable[]
---@param callback fun():nil
function M.watch_observables(observables, callback)
  local subscriber = Subscriber.new({
    onNext = function()
      callback()
    end,
  })
  for _, observable in ipairs(observables) do
    observable:subscribe(subscriber)
  end
end

return M
