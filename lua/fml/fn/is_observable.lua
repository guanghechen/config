---@param observable any
---@return boolean
local function is_observable(observable)
  return type(observable) == "table"
      and type(observable.snapshot) == "function"
      and type(observable.next) == "function"
      and type(observable.subscribe) == "function"
end

return is_observable
