---@class fc.collection.Disposable : fc.types.collection.IDisposable
---@field private _on_dispose           fun():nil
local M = {}
M.__index = M

---@class fc.collection.Disposable.IProps
---@field public on_dispose             fun():nil

---@param props fc.collection.Disposable.IProps
---@return fc.collection.Disposable
function M.new(props)
  local self = setmetatable({}, M)

  ---@type function
  self._on_dispose = props.on_dispose

  ---@type boolean
  self._disposed = false
  return self
end

---@param unsubscribable                fc.types.collection.IUnsubscribable
function M.from_unsubscribable(unsubscribable)
  return M.new({
    on_dispose = function()
      unsubscribable:unsubscribe()
    end,
  })
end

---@return boolean
function M:is_disposed()
  return self._disposed
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end

  self._disposed = true
  self._on_dispose()
end

return M
