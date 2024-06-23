---@param disposable any
---@return boolean
local function is_disposable(disposable)
  return type(disposable) == "table"
    and type(disposable.isDisposable) == "function"
    and type(disposable.dispose) == "function"
end

return is_disposable
