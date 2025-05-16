---@class eve.context.frecency.data
---@field public files                  std.collection.frecency.ISerializedData

---@class eve.context.frecency.state
---@field public files                  std.collection.IFrecency

---@class eve.context.frecency : eve.context.frecency.state
---@field public defaults               fun(): eve.context.frecency.data
---@field public dump                   fun(): eve.context.frecency.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): eve.context.frecency.data
local M = {}

---@return eve.context.frecency.data
function M.defaults()
  ---@type eve.context.frecency.data
  return {
    files = { items = {} },
  }
end

---@param data                        any
---@return eve.context.frecency.data
function M.normalize(data)
  local resolved = M.defaults() ---@type eve.context.frecency.data
  if type(data) == "table" then
    for key, frecency in pairs(resolved) do
      local data_frecency = data[key] ---@type std.collection.frecency.ISerializedData|nil
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

  ---@type eve.context.frecency.data
  return resolved
end

---@return eve.context.frecency.data
function M.dump()
  ---@type eve.context.frecency.data
  return {
    files = M.files:dump(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type eve.context.frecency.data

  M.files:load(data.files)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type eve.context.frecency.data

---@type std.collection.IFrecency
M.files = std.Frecency.deserialize({
  data = _defaults.files,
  normalize = function(key)
    return eve.oxi.md5(key)
  end,
})

return M
