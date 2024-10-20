local BatchDisposable = require("eve.collection.batch_disposable")
local Observable = require("eve.collection.observable")
local Subscriber = require("eve.collection.subscriber")

local disposables = BatchDisposable.new()

---@class eve.globals.mvc
---@field public tmux_zen_mode          t.eve.collection.IObservable
---@field public add_disposable         fun(disposable: t.eve.collection.IDisposable): nil
---@field public dispose                fun(): nil
local M = {
  tmux_zen_mode = Observable.from_value(false),
}

disposables:add_disposable(M.tmux_zen_mode)

---@param disposable                    t.eve.collection.IDisposable
---@return nil
function M.add_disposable(disposable)
  disposables:add_disposable(disposable)
end

---@return nil
function M.dispose()
  disposables:dispose()
end

---@param observables                   t.eve.collection.IObservable[]
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
