---@class dot.context.frecency.data
---@field public files                  ark.c.frecency.ISerializedData

---@class dot.context.frecency.state
---@field public files                  ark.c.Frecency

---@class dot.context.frecency : dot.context.frecency.state
---@field public defaults               fun(): dot.context.frecency.data
---@field public dump                   fun(): dot.context.frecency.data
---@field public load                   fun(data: unknown): nil
---@field public normalize              fun(data: unknown): dot.context.frecency.data
local M = {}

---@return dot.context.frecency.data
function M.defaults()
  ---@type dot.context.frecency.data
  return {
    files = { items = {} },
  }
end

---@param data                          any
---@return dot.context.frecency.data
function M.normalize(data)
  local resolved = M.defaults() ---@type dot.context.frecency.data
  if type(data) == "table" then
    for key, frecency in pairs(resolved) do
      local data_frecency = data[key] ---@type ark.c.frecency.ISerializedData|nil
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

  ---@type dot.context.frecency.data
  return resolved
end

---@return dot.context.frecency.data
function M.dump()
  ---@type dot.context.frecency.data
  return {
    files = M.files:dump(),
  }
end

---@param raw_data                      any
---@return nil
function M.load(raw_data)
  local data = M.normalize(raw_data) ---@type dot.context.frecency.data

  M.files:load(data.files)
end

----------------------------------------------------------------------------------------------------

local _defaults = M.defaults() ---@type dot.context.frecency.data

---@type ark.c.Frecency
M.files = ark.c.Frecency.deserialize({
  data = _defaults.files,
  normalize = function(key)
    return yoz.fn.md5(key)
  end,
})

return M
