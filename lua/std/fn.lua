---@class std.fn
local M = {}

---@param observables                   ark.c.IObservable[]
---@param callback                      fun(): nil
---@param ignore_initial                ?boolean
---@return ark.c.IUnsubscribable
function M.observe(observables, callback, ignore_initial)
  local unsubscribables = {} ---@type ark.c.IUnsubscribable[]
  for _, observable in ipairs(observables) do
    local subscriber = ark.c.Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    local unsubscribable = observable:subscribe(subscriber, ignore_initial)
    unsubscribables[#unsubscribables + 1] = unsubscribable
  end

  local unsubscribed = false ---@type boolean

  ---@type ark.c.IUnsubscribable
  local unsubscribe = {
    unsubscribe = function()
      if unsubscribed then
        return
      end
      unsubscribed = true

      local batcher = ark.c.BatchHandler.new()
      for _, unsubscribable in ipairs(unsubscribables) do
        batcher:run(unsubscribable.unsubscribe, unsubscribable)
      end
      batcher:summary("unsubscribable observers.")
    end,
  }
  return unsubscribe
end

return M
