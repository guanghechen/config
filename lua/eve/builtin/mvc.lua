local BatchDisposable = require("eve.lib.collection.batch_disposable")
local Subscriber = require("eve.lib.collection.subscriber")

local disposables = BatchDisposable.new()

---@class eve.builtin.mvc
---@field public add_disposable         fun(disposable: eve.lib.collection.IDisposable): nil
---@field public dispose                fun(): nil
local M = {}

---@param disposable                    eve.lib.collection.IDisposable
---@return nil
function M.add_disposable(disposable)
  disposables:add_disposable(disposable)
end

---@return nil
function M.dispose()
  disposables:dispose()
end

---@param observables                   eve.lib.collection.IObservable[]
---@param callback                      fun(): nil
---@param ignore_initial                ?boolean
---@return nil
function M.observe(observables, callback, ignore_initial)
  for _, observable in ipairs(observables) do
    local subscriber = Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    observable:subscribe(subscriber, ignore_initial)
  end
end

return M
