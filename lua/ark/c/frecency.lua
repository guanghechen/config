---@class ark.t.IFrecency
---@field public access                 fun(self: ark.t.IFrecency, key: string): nil
---@field public load                   fun(self: ark.t.IFrecency, data: ark.t.IFrecencySerializedData): nil
---@field public dump                   fun(self: ark.t.IFrecency): ark.t.IFrecencySerializedData
---@field public score                  fun(self: ark.t.IFrecency, key: string): number

---@class ark.t.IFrecencyItem
---@field public timestamps             integer[]
---@field public idx                    integer

---@class ark.t.IFrecencySerializedData
---@field public MAX_TIMESTAMPS         integer|nil
---@field public items                  ark.t.IFrecencyItem[]

---@class ark.t.IFrecencyProps
---@field public MAX_TIMESTAMPS         ?integer
---@field public items                  table<string, ark.t.IFrecencyItem>
---@field public normalize              ?fun(key: string): string

---@class ark.t.IFrecencyDeserializeProps
---@field public data                   ark.t.IFrecencySerializedData
---@field public normalize              ?fun(key: string): string

---@class ark.c.Frecency : ark.t.IFrecency
---@field public MAX_TIMESTAMPS         integer
---@field protected _items              table<string, ark.t.IFrecencyItem>
---@field protected _normalize          fun(key: string): string
local M = {}
M.__index = M

---@param props                         ark.t.IFrecencyProps
---@return ark.c.Frecency
function M.new(props)
  local self = setmetatable({}, M)

  local MAX_TIMESTAMPS = props.MAX_TIMESTAMPS or 10 ---@type integer
  local items = props.items ---@type table<string, ark.t.IFrecencyItem>
  local normalize = props.normalize or ark.fn.identity ---@type fun(key: string): string

  self.MAX_TIMESTAMPS = MAX_TIMESTAMPS
  self._items = items
  self._normalize = normalize

  return self
end

---@param props                         ark.t.IFrecencyDeserializeProps
---@return ark.c.Frecency
function M.deserialize(props)
  local data = props.data ---@type ark.t.IFrecencySerializedData
  local normalize = props.normalize ---@type (fun(key: string): string)|nil
  return M.new({
    MAX_TIMESTAMPS = data.MAX_TIMESTAMPS,
    items = data.items,
    normalize = normalize,
  })
end

---@param key                           string
---@return nil
function M:access(key)
  key = self._normalize(key)
  local timestamp = os.time() ---@type integer
  local item = self._items[key] ---@type ark.t.IFrecencyItem|nil
  if item == nil then
    item = { timestamps = { timestamp }, idx = 1 } ---@type ark.t.IFrecencyItem
    self._items[key] = item
  else
    local idx = item.idx == self.MAX_TIMESTAMPS and 1 or item.idx + 1 ---@type integer
    item.idx = idx
    item.timestamps[idx] = timestamp
  end
end

---@return ark.t.IFrecencySerializedData
function M:dump()
  ---@type ark.t.IFrecencySerializedData
  local data = {
    MAX_TIMESTAMPS = self.MAX_TIMESTAMPS,
    items = self._items,
  }
  return data
end

---@param data                          ark.t.IFrecencySerializedData
---@return nil
function M:load(data)
  local items = data.items ---@type ark.t.IFrecencyItem[]
  self._items = items
end

---@param key                           string
---@return number
function M:score(key)
  key = self._normalize(key)
  local timestamp_cur = os.time() ---@type integer
  local item = self._items[key] ---@type ark.t.IFrecencyItem|nil
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
