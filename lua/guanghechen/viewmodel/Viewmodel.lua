local BatchDisposable = require("guanghechen.disposable.BatchDisposable")

---@class guanghechen.viewmodel.Viewmodel.util
local util = {
  disposable = require("guanghechen.util.disposable"),
}

---@class guanghechen.viewmodel.Viewmodel : guanghechen.types.IViewmodel
local Viewmodel = setmetatable({}, BatchDisposable)

---@param o guanghechen.types.IBatchDisposable
---@return guanghechen.viewmodel.Viewmodel
function Viewmodel:new(o)
  o = o or BatchDisposable:new()

  ---@type guanghechen.types.IBatchDisposable
  self._super = o

  ---@cast o guanghechen.viewmodel.Viewmodel
  return o
end

---@return nil
function Viewmodel:dispose()
  if self:isDisposed() then
    return
  end

  self._super:dispose()

  ---@type guanghechen.types.IDisposable[]
  local disposables = {}
  for key, disposable in pairs(self) do
    if type(key) == "string" and key[#key] == "$" then
      ---@cast disposable guanghechen.types.IDisposable
      table.insert(disposables, disposable)
    end
  end

  util.disposable.disposeAll(disposables)
end

return Viewmodel
