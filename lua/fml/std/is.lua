---@class fml.std.is
local M = {}

---@param disposable                    any
---@return boolean
function M.disposable(disposable)
  return type(disposable) == "table"
    and type(disposable.isDisposable) == "function"
    and type(disposable.dispose) == "function"
end

---@param observable                    any
---@return boolean
function M.observable(observable)
  return type(observable) == "table"
    and type(observable.snapshot) == "function"
    and type(observable.next) == "function"
    and type(observable.subscribe) == "function"
end

return M
