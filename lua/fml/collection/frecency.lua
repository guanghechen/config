---@class fml.collection.Frecency : fml.types.collection.IFrecency
---@field private MAX_TIMESTAMPS        integer
---@field private MIN_SCORE_THRESHOLD   number
---@field private _items                table<string, fml.types.collection.IFrecencyItem>
local M = {}
M.__index = M

---@class fml.collection.frecency.IProps
---@field public MAX_TIMESTAMPS         ?integer
---@field public MIN_SCORE_THRESHOLD    ?number
---@field public items                  table<string, fml.types.collection.IFrecencyItem>

---@param props                         fml.collection.frecency.IProps
---@return fml.collection.Frecency
function M.new(props)
  local self = setmetatable({}, M)

  local MAX_TIMESTAMPS = props.MAX_TIMESTAMPS or 10 ---@type integer
  local MIN_SCORE_THRESHOLD = props.MIN_SCORE_THRESHOLD or 1e-9 ---@type number
  local items = props.items ---@type table<string, fml.types.collection.IFrecencyItem>

  self.MAX_TIMESTAMPS = MAX_TIMESTAMPS
  self.MIN_SCORE_THRESHOLD = MIN_SCORE_THRESHOLD
  self._items = items

  return self
end

---@param uuid                          string
---@return nil
function M:access(uuid)
  local timestamp = os.time() ---@type integer
  local item = self._items[uuid] ---@type fml.types.collection.IFrecencyItem|nil
  if item == nil then
    item = { timestamps = { timestamp }, idx = 1 } ---@type fml.types.collection.IFrecencyItem
    self._items[uuid] = item
  else
    local idx = item.idx == self.MAX_TIMESTAMPS and 1 or item.idx + 1 ---@type integer
    item.idx = idx
    item.timestamps[idx] = timestamp
  end
end

---@param uuid                          string
---@return number
function M:score(uuid)
  local timestamp_cur = os.time() ---@type integer
  local item = self._items[uuid] ---@type fml.types.collection.IFrecencyItem|nil
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
  if score < self.MIN_SCORE_THRESHOLD then
    score = self.MIN_SCORE_THRESHOLD
    self._items[uuid] = nil
  end

  return score
end

return M
