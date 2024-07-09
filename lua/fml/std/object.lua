---@class fml.std.object
local M = {}

---@generic K
---@generic V
---@param object                        table<K, V>
---@param filter                        fun(v: V, k: K, object: table<K, V>): boolean
---@return table<K, V>
function M.filter(object, filter)
  local result = {}
  for key, val in pairs(object) do
    if filter(val, key, object) then
      result[key] = val
    end
  end
  return result
end

---@generic K
---@generic V
---@param object                        table<K, V>
---@param filter                        fun(v: V, k: K, object: table<K, V>): boolean
---@return table<K, V>
function M.filter_inline(object, filter)
  local keys_to_remove = {}
  for key, val in pairs(object) do
    if not filter(val, key, object) then
      table.insert(keys_to_remove, key)
    end
  end
  for _, key in ipairs(keys_to_remove) do
    object[key] = nil
  end
  return object
end

---@generic K
---@generic V
---@param object                        table<K, V>
---@param filter                        fun(v: V, k: K, object: table<K, V>): boolean
---@return K|nil
---@return V|nil
function M.find(object, filter)
  for key, val in pairs(object) do
    if filter(val, key, object) then
      return key, val
    end
  end
  return nil, nil
end

return M
