local functional = require("eve.lib.functional")

---@class eve.lib.collection.IFrecency
---@field public access                 fun(self: eve.lib.collection.IFrecency, key: string): nil
---@field public load                   fun(self: eve.lib.collection.IFrecency, data: eve.lib.collection.frecency.ISerializedData): nil
---@field public dump                   fun(self: eve.lib.collection.IFrecency): eve.lib.collection.frecency.ISerializedData
---@field public score                  fun(self: eve.lib.collection.IFrecency, key: string): number

---@class eve.lib.collection.frecency.IItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class eve.lib.collection.frecency.ISerializedData
---@field public MAX_TIMESTAMPS         integer|nil
---@field public items                  eve.lib.collection.frecency.IItem[]

---@class eve.lib.collection.frecency.IProps
---@field public MAX_TIMESTAMPS         ?integer
---@field public items                  table<string, eve.lib.collection.frecency.IItem>
---@field public normalize              ?fun(key: string): string

---@class eve.lib.collection.frecency.IDeserializeProps
---@field public data                   eve.lib.collection.frecency.ISerializedData
---@field public normalize              ?fun(key: string): string

---@class eve.lib.collection.Frecency : eve.lib.collection.IFrecency
---@field public MAX_TIMESTAMPS         integer
---@field protected _items              table<string, eve.lib.collection.frecency.IItem>
---@field protected _normalize          fun(key: string): string
local M = {}
M.__index = M

---@param props                         eve.lib.collection.frecency.IProps
---@return eve.lib.collection.Frecency
function M.new(props)
  local self = setmetatable({}, M)

  local MAX_TIMESTAMPS = props.MAX_TIMESTAMPS or 10 ---@type integer
  local items = props.items ---@type table<string, eve.lib.collection.frecency.IItem>
  local normalize = props.normalize or functional.identity ---@type fun(key: string): string

  self.MAX_TIMESTAMPS = MAX_TIMESTAMPS
  self._items = items
  self._normalize = normalize

  return self
end

---@param props                         eve.lib.collection.frecency.IDeserializeProps
---@return eve.lib.collection.Frecency
function M.deserialize(props)
  local data = props.data ---@type eve.lib.collection.frecency.ISerializedData
  local normalize = props.normalize ---@type (fun(key: string): string)|nil
  return M.new({
    MAX_TIMESTAMP = data.MAX_TIMESTAMPS,
    items = data.items,
    normalize = normalize,
  })
end

---@param key                          string
---@return nil
function M:access(key)
  key = self._normalize(key)
  local timestamp = os.time() ---@type integer
  local item = self._items[key] ---@type eve.lib.collection.frecency.IItem|nil
  if item == nil then
    item = { timestamps = { timestamp }, idx = 1 } ---@type eve.lib.collection.frecency.IItem
    self._items[key] = item
  else
    local idx = item.idx == self.MAX_TIMESTAMPS and 1 or item.idx + 1 ---@type integer
    item.idx = idx
    item.timestamps[idx] = timestamp
  end
end

---@return eve.lib.collection.frecency.ISerializedData
function M:dump()
  ---@type eve.lib.collection.frecency.ISerializedData
  local data = {
    MAX_TIMESTAMPS = self.MAX_TIMESTAMPS,
    items = self._items,
  }
  return data
end

---@param data                          eve.lib.collection.frecency.ISerializedData
---@return nil
function M:load(data)
  local items = data.items ---@type eve.lib.collection.frecency.IItem[]
  self._items = items
end

---@param key                          string
---@return number
function M:score(key)
  key = self._normalize(key)
  local timestamp_cur = os.time() ---@type integer
  local item = self._items[key] ---@type eve.lib.collection.frecency.IItem|nil
  local score = 0 ---@type number
  if item ~= nil then
    for _, timestamp in ipairs(item.timestamps) do
      local delta = timestamp_cur - timestamp ---@type integer
      if delta <= 1800 then --- 30 minutes
        score = score + 10
      elseif delta <= 3600 then --- 1 hour
        score = score + 9
      elseif delta <= 86400 then --- 1 day
        score = score + 7
      elseif delta <= 259200 then --- 3 day
        score = score + 6
      elseif delta <= 604800 then --- 7 day
        score = score + 5
      elseif delta <= 1209600 then --- 14 day
        score = score + 3
      elseif delta <= 2592000 then --- 30 day
        score = score + 1
      end
    end
  end

  ---! Remove the item if the score is below the threshold.
  if score <= 0 then
    score = 0
    self._items[key] = nil
  end

  return score
end

return M
