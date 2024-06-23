local Subscriber = require("fml.collection.subscriber")

---@param observables fml.types.collection.IObservable[]
---@param callback fun():nil
local function watch_observables(observables, callback)
  local subscriber = Subscriber.new({
    on_next = function()
      callback()
    end,
  })
  for _, observable in ipairs(observables) do
    observable:subscribe(subscriber)
  end
end

return watch_observables
