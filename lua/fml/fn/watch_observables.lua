local Subscriber = require("fml.collection.subscriber")

---@param observables                   fml.types.collection.IObservable[]
---@param callback                      fun():nil
---@param ignore_initial                ?boolean
---@return nil
local function watch_observables(observables, callback, ignore_initial)
  ignore_initial = not not ignore_initial
  for _, observable in ipairs(observables) do
    local first = true ---@type boolean
    local subscriber = Subscriber.new({
      on_next = function()
        if first then
          first = false
          if not ignore_initial then
            callback()
          end
        else
          callback()
        end
      end,
    })
    observable:subscribe(subscriber)
  end
end

return watch_observables
