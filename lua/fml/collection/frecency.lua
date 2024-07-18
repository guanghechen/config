---@class fml.std.Frecency
---@field private MAX_TIMESTAMPS        integer
---@field private MIN_SCORE_THRESHOLD   number
---@field private _items                table<string, fml.types.collection.IFrecencyItem>
local M = {}
M.__index = M

---@class fml.std.frecency.IProps
---@field public MAX_TIMESTAMPS         ?integer
---@field public MIN_SCORE_THRESHOLD    ?number
---@field public items                  table<string, fml.types.collection.IFrecencyItem>

---@param props                         fml.std.frecency.IProps
---@return fml.std.Frecency
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
      local delta = timestamp < timestamp_cur and timestamp_cur - timestamp or 1 ---@type integer
      score = score + 1 / delta
    end
  end
  return score
end

return M
