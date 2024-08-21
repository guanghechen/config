local Observable = require("fml.collection.observable")
local Subscriber = require("fml.collection.subscriber")
local scheduler = require("fml.std.scheduler")
local navigate = require("fml.std.navigate")
local oxi = require("fml.std.oxi")

---@class fml.ui.search.State : fml.types.ui.search.IState
---@field protected _item_lnum_cur      integer
---@field protected _item_uuid_cur      string|nil
local M = {}
M.__index = M

---@class fml.ui.search.state.IProps
---@field public title                  string
---@field public enable_multiline_input boolean
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public fetch_items            fml.types.ui.search.IFetchItems
---@field public fetch_delay            integer

---@param props                         fml.ui.search.state.IProps
---@return fml.ui.search.State
function M.new(props)
  local self = setmetatable({}, M)

  local uuid = oxi.uuid() ---@type string
  local title = props.title ---@type string
  local enable_multiline_input = props.enable_multiline_input ---@type boolean
  local input = props.input ---@type fml.types.collection.IObservable
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local fetch_items = props.fetch_items ---@type fml.types.ui.search.IFetchItems
  local fetch_delay = props.fetch_delay ---@type integer
  local visible = Observable.from_value(false)
  local dirty_items = Observable.from_value(true)
  local dirty_main = Observable.from_value(false)
  local dirty_preview = Observable.from_value(false)
  local input_line_count = Observable.from_value(oxi.count_lines(input:snapshot())) ---@type fml.types.collection.IObservable

  local fetch_scheduler ---@type fml.std.scheduler.IScheduler
  fetch_scheduler = scheduler.debounce({
    name = "fml.ui.search.state.fetch",
    delay = fetch_delay,
    fn = function(callback)
      local input_cur = input:snapshot() ---@type string
      fetch_items(input_cur, function(succeed, items)
        if succeed and items ~= nil then
          local max_width = 0 ---@type integer
          local item_lnum_next = 1 ---@type integer
          ---@diagnostic disable-next-line: invisible
          local item_uuid_cur = self._item_uuid_cur ---@type string|nil
          for lnum, item in ipairs(items) do
            local width = vim.fn.strwidth(item.text) ---@type integer
            max_width = max_width < width and width or max_width

            if item.uuid == item_uuid_cur then
              item_lnum_next = lnum
            end
          end

          self.items = items
          self.max_width = max_width
          self:locate(item_lnum_next)
          callback(true)
        else
          callback(false, items)
        end
      end)
    end,
    callback = function(ok)
      dirty_items:next(false)
      if ok then
        dirty_main:next(true, { force = true })
        dirty_preview:next(true, { force = true })
      end
    end,
  })

  ---@return nil
  local function on_input_change()
    if enable_multiline_input then
      local line_count = oxi.count_lines(input:snapshot())
      input_line_count:next(line_count)
    end
    self:mark_dirty()
  end

  ---@return nil
  local function on_items_dirty()
    local is_visible = visible:snapshot() ---@type boolean
    if is_visible then
      self:mark_dirty()
    end
  end

  ---@return nil
  local function on_visible_change()
    local is_visible = visible:snapshot() ---@type boolean
    local is_item_dirty = dirty_items:snapshot() ---@type boolean
    if is_visible and is_item_dirty then
      fetch_scheduler.schedule()
    end
  end

  self.uuid = uuid
  self.title = title
  self.enable_multiline_input = enable_multiline_input
  self.input = input
  self.input_line_count = input_line_count
  self.input_history = input_history
  self.visible = visible
  self.dirty_items = dirty_items
  self.dirty_main = dirty_main
  self.dirty_preview = dirty_preview
  self.items = {} ---@type fml.types.ui.search.IItem[]
  self.max_width = 0 ---@type integer
  self._item_lnum_cur = 1 ---@type integer
  self._item_uuid_cur = nil ---@type string|nil

  dirty_items:subscribe(Subscriber.new({ on_next = on_items_dirty }))
  input:subscribe(Subscriber.new({ on_next = on_input_change }))
  visible:subscribe(Subscriber.new({ on_next = on_visible_change }))
  return self
end

---@return nil
function M:dispose()
  self.dirty_items:dispose()
  self.dirty_main:dispose()
  self.dirty_preview:dispose()
  self.visible:dispose()
end

---@return fml.types.ui.search.IItem|nil
---@return integer
---@return string|nil
function M:get_current()
  local lnum = self._item_lnum_cur ---@type integer
  local uuid = self._item_uuid_cur ---@type string|nil
  return self.items[lnum], lnum, uuid
end

---@return integer
function M:get_current_lnum()
  return self._item_lnum_cur
end

---@param lnum                          integer
---@return integer
function M:locate(lnum)
  local items = self.items ---@type fml.types.ui.search.IItem[]
  local next_lnum = math.max(1, math.min(#items, lnum)) ---@type integer
  local next_uuid = items[next_lnum] and items[next_lnum].uuid or nil ---@type string|nil
  local has_changed = self._item_lnum_cur ~= next_lnum or self._item_uuid_cur ~= next_uuid ---@type boolean
  if has_changed then
    self.dirty_preview:next(true)
  end

  self._item_lnum_cur = next_lnum
  self._item_uuid_cur = next_uuid
  return next_lnum
end

---@return nil
function M:mark_dirty()
  self.dirty_items:next(true)
end

---@return integer
function M:moveup()
  local step = vim.v.count1 or 1 ---@type integer
  local items = self.items ---@type fml.types.ui.search.IItem[]
  local lnum = navigate.circular(self._item_lnum_cur, -step, #items) ---@type integer
  return self:locate(lnum)
end

---@return integer
function M:movedown()
  local step = vim.v.count1 or 1 ---@type integer
  local items = self.items ---@type fml.types.ui.search.IItem[]
  local lnum = navigate.circular(self._item_lnum_cur, step, #items) ---@type integer
  return self:locate(lnum)
end

return M
