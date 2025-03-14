local md5 = require("eve.lib.md5")

---@class eve.state.frecency.data
---@field public files                  eve.collection.frecency.ISerializedData

---@class eve.state.frecency.state
---@field public files                  eve.collection.IFrecency

---@class eve.state.frecency
---@field public defaults               fun(): eve.state.frecency.data
---@field public dump                   fun(): eve.state.frecency.data
---@field public load                   fun(data: unknown): eve.state.frecency.state
---@field public normalize              fun(data: unknown): eve.state.frecency.data
local M = {}

local _state = nil ---@type eve.state.frecency.state | nil

---@return eve.state.frecency.data
function M.defaults()
  ---@type eve.state.frecency.data
  return {
    files = { items = {} },
  }
end

---@param data                        any
---@return eve.state.frecency.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.state.frecency.data
  if type(data) == "table" then
    for key, frecency in pairs(resolved) do
      local data_frecency = data[key] ---@type eve.collection.frecency.ISerializedData|nil
      if type(data_frecency) == "table" then
        if type(data_frecency.MAX_TIMESTAMPS) == "number" then
          frecency.MAX_TIMESTAMPS = data_frecency.MAX_TIMESTAMPS
        end
        if type(data_frecency.items) == "table" then
          frecency.items = data_frecency.items
        end
      end
    end
  end

  ---@type eve.state.frecency.data
  return resolved
end

---@return eve.state.frecency.data
function M.dump()
  if _state == nil then
    ---@type eve.state.frecency.data
    return M.defaults()
  end

  ---@type eve.state.frecency.data
  return {
    files = _state.files:dump(),
  }
end

---@param raw_data                      any
---@return eve.state.frecency.state
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.state.frecency.data

  if _state == nil then
    ---@type eve.state.frecency.state
    _state = {
      files = eve.c.Frecency.deserialize({
        data = data.files,
        normalize = function(key)
          return md5.sumhexa(key)
        end,
      }),
    }
    return _state
  end

  _state.files:load(data.files)
  return _state
end

return M
