local Observable = require("fml.collection.observable")
local Subscriber = require("fml.collection.subscriber")
local navigate = require("fml.std.navigate")
local oxi = require("fml.std.oxi")

---@class fml.ui.search.State : fml.types.ui.search.IState
---@field protected _item_lnum_cur      integer
---@field protected _item_uuid_cur      string|nil
local M = {}
M.__index = M

---@class fml.ui.search.state.IProps
---@field public title                  string
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public fetch_items            fml.types.ui.search.IFetchItems
---@field public fetch_delay            ?integer

function M.new(props)
  local self = setmetatable({}, M)

  local uuid = oxi.uuid() ---@type string
  local title = props.title ---@type string
  local input = props.input ---@type fml.types.collection.IObservable
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local fetch_items = props.fetch_items ---@type fml.types.ui.search.IFetchItems
  local fetch_delay = math.max(0, props.fetch_delay or 32) ---@type integer
  local visible = Observable.from_value(false)
  local dirty_items = Observable.from_value(true)
  local dirty_main = Observable.from_value(true)

  self.uuid = uuid
  self.title = title
  self.input = input
  self.input_history = input_history
  self.visible = visible
  self.dirty_items = dirty_items
  self.dirty_main = dirty_main
  self.items = {} ---@type fml.types.ui.search.IItem[]
  self.max_width = 0 ---@type integer
  self._item_lnum_cur = 1 ---@type integer
  self._item_uuid_cur = nil ---@type string|nil

  local fetching = false ---@type boolean
  local function fetch()
    local is_dirty = dirty_items:snapshot() ---@type boolean
    local is_visible = visible:snapshot() ---@type boolean

    if fetching or not is_dirty or not is_visible then
      return
    end

    fetching = true
    dirty_items:next(false)

    local input_cur = input:snapshot() ---@type string
    fetch_items(input_cur, function(succeed, items)
      fetching = false

      if succeed and items ~= nil then
        local max_width = 0 ---@type integer
        for _, item in ipairs(items) do
          local width = vim.fn.strwidth(item.text) ---@type integer
          max_width = max_width < width and width or max_width
        end

        self.items = items
        self.max_width = max_width
        dirty_main:next(true)
      end

      vim.schedule(fetch)
    end)
  end

  ---@return nil
  local function fetch_deferred()
    vim.defer_fn(fetch, fetch_delay)
  end

  ---@return nil
  local function mark_dirty()
    self:mark_items_dirty()
  end

  input:subscribe(Subscriber.new({ on_next = mark_dirty }))
  dirty_items:subscribe(Subscriber.new({ on_next = fetch_deferred }))
  visible:subscribe(Subscriber.new({ on_next = fetch_deferred }))

  return self
end

---@return nil
function M:dispose()
  self.dirty_items:dispose()
  self.dirty_main:dispose()
  self.visible:dispose()
end

---@return fml.types.ui.search.IItem|nil
---@return integer
function M:get_current()
  local lnum = self._item_lnum_cur ---@type integer
  return self.items[lnum], lnum
end

---@param lnum                          integer
---@return integer
function M:locate(lnum)
  local items = self.items ---@type fml.types.ui.search.IItem[]
  lnum = math.max(1, math.min(#items, lnum)) ---@type integer
  self._item_lnum_cur = lnum ---@type integer
  self._item_uuid_cur = items[lnum] and items[lnum].uuid or nil ---@type string|nil
  return lnum
end

---@return nil
function M:mark_items_dirty()
  self.dirty_items:next(true)
end

---@return integer
function M:moveup()
  local step = vim.v.count1 or 1 ---@type integer
  local items = self.items ---@type fml.types.ui.search.IItem[]
  local lnum = math.max(1, navigate.circular(self._item_lnum_cur, -step, #items)) ---@type integer
  self._item_lnum_cur = lnum ---@type integer
  self._item_uuid_cur = items[lnum] and items[lnum].uuid or nil ---@type string|nil
  return lnum
end

---@return integer
function M:movedown()
  local step = vim.v.count1 or 1 ---@type integer
  local items = self.items ---@type fml.types.ui.search.IItem[]
  local lnum = math.max(1, navigate.circular(self._item_lnum_cur, step, #items)) ---@type integer
  self._item_lnum_cur = lnum ---@type integer
  self._item_uuid_cur = items[lnum] and items[lnum].uuid or nil ---@type string|nil
  return lnum
end

return M
