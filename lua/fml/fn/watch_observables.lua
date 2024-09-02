---@param observables                   eve.types.collection.IObservable[]
---@param callback                      fun():nil
---@param ignore_initial                ?boolean
---@return nil
local function watch_observables(observables, callback, ignore_initial)
  for _, observable in ipairs(observables) do
    local subscriber = eve.c.Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    observable:subscribe(subscriber, ignore_initial)
  end
end

return watch_observables
