---@class fml.collection.Disposable : fml.types.collection.IDisposable
---@field private _on_dispose           fun():nil
local M = {}
M.__index = M

---@class fml.collection.Disposable.IProps
---@field public on_dispose             fun():nil

---@param props fml.collection.Disposable.IProps
---@return fml.collection.Disposable
function M.new(props)
  local self = setmetatable({}, M)

  ---@type function
  self._on_dispose = props.on_dispose

  ---@type boolean
  self._disposed = false
  return self
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
