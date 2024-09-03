local BatchDisposable = require("eve.collection.batch_disposable")
local Observable = require("eve.collection.observable")

local disposables = BatchDisposable.new()

---@class eve.globals.mvc
---@field public tmux_zen_mode          eve.types.collection.IObservable
---@field public add_disposable         fun(disposable: eve.types.collection.IDisposable): nil
---@field public dispose                fun(): nil
local M = {
  tmux_zen_mode = Observable.from_value(false),
}

disposables:add_disposable(M.tmux_zen_mode)

---@param disposable                    eve.types.collection.IDisposable
---@return nil
function M.add_disposable(disposable)
  disposables:add_disposable(disposable)
end

---@return nil
function M.dispose()
  disposables:dispose()
end

---@param observables                   eve.types.collection.IObservable[]
---@param callback                      fun(): nil
---@param ignore_initial                ?boolean
---@return nil
function M.observe(observables, callback, ignore_initial)
  for _, observable in ipairs(observables) do
    local subscriber = eve.c.Subscriber.new({
      on_next = function()
        vim.schedule(callback)
      end,
    })
    observable:subscribe(subscriber, ignore_initial)
  end
end

return M
