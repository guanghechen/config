local Observable = require("fml.collection.observable")
local Subscriber = require("fml.collection.subscriber")
local scheduler = require("fml.std.scheduler")
local navigate = require("fml.std.navigate")
local oxi = require("fml.std.oxi")
local reporter = require("fml.std.reporter")

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
  local dirty_preview = Observable.from_value(true)

  local fetch_scheduler ---@type fml.std.scheduler.IRunner
  fetch_scheduler = scheduler.debounce({
    delay = fetch_delay,
    fn = function(callback)
      local input_cur = input:snapshot() ---@type string
      fetch_items(input_cur, function(succeed, items)
        local ok, ok2 = pcall(
          ---@return boolean
          function()
            if succeed and items ~= nil then
              local max_width = 0 ---@type integer
              local item_lnum_next = 1 ---@type integer
              ---@diagnostic disable-next-line: invisible
              local item_uuid_cur = self._item_uuid_cur ---@type string|nil
              for _, item in ipairs(items) do
                local width = vim.fn.strwidth(item.text) ---@type integer
                max_width = max_width < width and width or max_width

                if item.uuid == item_uuid_cur then
                  item_lnum_next = item_lnum_next
                end
              end

              self.items = items
              self.max_width = max_width
              self:locate(item_lnum_next)

              dirty_items:next(false)
              dirty_main:next(true)
              dirty_preview:next(true)
              return true
            else
              reporter.error({
                from = "fml.ui.search.state",
                subject = "fetch_items",
                message = "Failed to fetch items.",
                details = { input = input_cur, error = items },
              })
              return false
            end
          end
        )

        callback(ok and ok2)
      end)
    end,
  })

  ---@return nil
  local function fetch()
    fetch_scheduler.schedule()
  end

  ---@return nil
  local function mark_dirty()
    self:mark_dirty()
  end

  self.uuid = uuid
  self.title = title
  self.input = input
  self.input_history = input_history
  self.visible = visible
  self.dirty_items = dirty_items
  self.dirty_main = dirty_main
  self.dirty_preview = dirty_preview
  self.items = {} ---@type fml.types.ui.search.IItem[]
  self.max_width = 0 ---@type integer
  self._item_lnum_cur = 1 ---@type integer
  self._item_uuid_cur = nil ---@type string|nil

  input:subscribe(Subscriber.new({ on_next = mark_dirty }))
  dirty_items:subscribe(Subscriber.new({ on_next = fetch }))
  visible:subscribe(Subscriber.new({ on_next = fetch }))
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

---@param lnum                          integer
---@return integer
function M:locate(lnum)
  local items = self.items ---@type fml.types.ui.search.IItem[]
  local next_lnum = math.max(1, math.min(#items, lnum)) ---@type integer
  local next_uuid = items[next_lnum] and items[next_lnum].uuid or nil ---@type string|nil
  local has_changed = self._item_lnum_cur ~= next_lnum or self._item_uuid_cur ~= next_uuid

  self._item_lnum_cur = next_lnum
  self._item_uuid_cur = next_uuid

  if has_changed then
    vim.schedule(function()
      self.dirty_preview:next(true)
    end)
  end

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
