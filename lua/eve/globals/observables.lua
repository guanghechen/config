local BatchDisposable = require("eve.collection.batch_disposable")
local Observable = require("eve.collection.observable")

local disposables = BatchDisposable.new()

---@class eve.globals.observables
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

return M
