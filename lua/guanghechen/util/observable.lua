---@class guanghechen.util.observable
local M = {}

---@param observable any
---@return boolean
function M.isObservable(observable)
  return type(observable) == "table"
    and type(observable.get_snapshot) == "function"
    and type(observable.next) == "function"
    and type(observable.subscribe) == "function"
end

return M
