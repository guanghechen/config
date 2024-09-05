local Dirtier = require("eve.collection.dirtier")
local Observable = require("eve.collection.observable")
local Subscriber = require("eve.collection.subscriber")
local scheduler = require("eve.std.scheduler")
local navigate = require("eve.std.navigate")

---@class fml.ui.search.State : fml.types.ui.search.IState
---@field protected _deleted_uuids      table<string, boolean>
---@field protected _item_lnum_cur      integer
---@field protected _item_uuid_cur      string|nil
local M = {}
M.__index = M

---@class fml.ui.search.state.IProps
---@field public enable_multiline_input boolean
---@field public fetch_data             fml.types.ui.search.IFetchData
---@field public delay_fetch            integer
---@field public input                  eve.types.collection.IObservable
---@field public input_history          eve.types.collection.IHistory|nil
---@field public title                  string

---@param props                         fml.ui.search.state.IProps
---@return fml.ui.search.State
function M.new(props)
  local self = setmetatable({}, M)

  local dirtier_dimension = Dirtier.new() ---@type eve.types.collection.IDirtier
  local dirtier_data = Dirtier.new() ---@type eve.types.collection.IDirtier
  local dirtier_data_cache = Dirtier.new() ---@type eve.types.collection.IDirtier
  local dirtier_main = Dirtier.new() ---@type eve.types.collection.IDirtier
  local dirtier_preview = Dirtier.new() ---@type eve.types.collection.IDirtier
  local enable_multiline_input = props.enable_multiline_input ---@type boolean
  local fetch_data = props.fetch_data ---@type fml.types.ui.search.IFetchData
  local delay_fetch = props.delay_fetch ---@type integer
  local input = props.input ---@type eve.types.collection.IObservable
  local input_history = props.input_history ---@type eve.types.collection.IHistory|nil
  local input_line_count = Observable.from_value(eve.oxi.count_lines(input:snapshot())) ---@type eve.types.collection.IObservable
  local title = props.title ---@type string
  local uuid = eve.oxi.uuid() ---@type string
  local visible = Observable.from_value(false)

  local fetch_scheduler ---@type eve.std.scheduler.IScheduler
  fetch_scheduler = scheduler.debounce({
    name = "fml.ui.search.state.fetch",
    delay = delay_fetch,
    fn = function(callback)
      local input_cur = input:snapshot() ---@type string
      local force = dirtier_data_cache:is_dirty() ---@type boolean
      dirtier_data_cache:mark_clean()
      fetch_data(input_cur, force, function(succeed, data)
        if succeed and data ~= nil then
          local max_width = 0 ---@type integer
          local item_lnum_next = 1 ---@type integer
          local items = data.items ---@type fml.types.ui.search.IItem[]
          local present_uuid = data.present_uuid ---@type string|nil
          local cursor_uuid = data.cursor_uuid or data.present_uuid ---@type string|nil

          ---@diagnostic disable-next-line: invisible
          local item_uuid_cur = cursor_uuid or self._item_uuid_cur ---@type string|nil
          for lnum, item in ipairs(items) do
            local width = vim.fn.strwidth(item.text) ---@type integer
            max_width = max_width < width and width or max_width

            if item.uuid == item_uuid_cur then
              item_lnum_next = lnum
            end
          end

          self.item_present_uuid = present_uuid
          self.items = items
          self.max_width = max_width
          self:locate(item_lnum_next)
          callback(true)
        else
          callback(false, data)
        end
      end)
    end,
    callback = function(ok)
      self.dirtier_data:mark_clean()
      if ok then
        ---@diagnostic disable-next-line: invisible
        self._deleted_uuids = {} ---@type table<string, boolean>
        self.dirtier_main:mark_dirty()
        self.dirtier_preview:mark_dirty()
      end
    end,
  })

  ---@return nil
  local function on_input_change()
    if enable_multiline_input then
      local line_count = eve.oxi.count_lines(input:snapshot())
      input_line_count:next(line_count)
    end
    self.dirtier_data:mark_dirty()
  end

  ---@return nil
  local function on_visible_or_data_change()
    local is_visible = visible:snapshot() ---@type boolean
    local is_data_dirty = self.dirtier_data:is_dirty() ---@type boolean
    if is_visible and is_data_dirty then
      fetch_scheduler.schedule()
    end
  end

  self.dirtier_dimension = dirtier_dimension
  self.dirtier_data = dirtier_data
  self.dirtier_data_cache = dirtier_data_cache
  self.dirtier_main = dirtier_main
  self.dirtier_preview = dirtier_preview
  self.enable_multiline_input = enable_multiline_input
  self.input = input
  self.input_history = input_history
  self.input_line_count = input_line_count
  self.item_present_uuid = nil
  self.items = {} ---@type fml.types.ui.search.IItem[]
  self.max_width = 0 ---@type integer
  self.title = title
  self.uuid = uuid
  self.visible = visible
  self._deleted_uuids = {} ---@type table<string, boolean>
  self._item_lnum_cur = 1 ---@type integer
  self._item_uuid_cur = nil ---@type string|nil

  input:subscribe(Subscriber.new({ on_next = on_input_change }), false)
  visible:subscribe(Subscriber.new({ on_next = on_visible_or_data_change }), false)
  dirtier_data:subscribe(Subscriber.new({ on_next = on_visible_or_data_change }), false)
  return self
end

---@return nil
function M:dispose()
  self.dirtier_dimension:dispose()
  self.dirtier_data:dispose()
  self.dirtier_main:dispose()
  self.dirtier_preview:dispose()
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

---@return string|nil
function M:get_current_uuid()
  return self._item_uuid_cur
end

---@param uuid                          string
---@return boolean
function M:has_item_deleted(uuid)
  return self._deleted_uuids[uuid] ~= nil
end

---@param lnum                          integer
---@return integer
function M:locate(lnum)
  local items = self.items ---@type fml.types.ui.search.IItem[]
  local next_lnum = math.max(1, math.min(#items, lnum)) ---@type integer
  local next_uuid = items[next_lnum] and items[next_lnum].uuid or nil ---@type string|nil
  local has_changed = self._item_lnum_cur ~= next_lnum or self._item_uuid_cur ~= next_uuid ---@type boolean
  if has_changed then
    self.dirtier_preview:mark_dirty()
  end

  self._item_lnum_cur = next_lnum
  self._item_uuid_cur = next_uuid
  return next_lnum
end

---@param uuid                          string
---@return nil
function M:mark_item_deleted(uuid)
  local deleted_uuids = self._deleted_uuids ---@type table<string, boolean>
  local lnum = 0 ---@type integer
  local items = self.items ---@type fml.types.ui.search.IItem[]

  for i, item in ipairs(self.items) do
    if item.uuid == uuid then
      lnum = i
      break
    end
  end

  if lnum < 1 then
    return
  end

  deleted_uuids[uuid] = true
  local parent_cur = items[lnum].parent ---@type string|nil
  if parent_cur ~= nil and lnum > 1 and items[lnum - 1].uuid == parent_cur then
    if lnum == #items or items[lnum + 1].parent ~= parent_cur then
      lnum = lnum - 1
      deleted_uuids[parent_cur] = true
    end
  end

  local k = lnum ---@type integer
  local N = #items ---@type integer
  for i = lnum + 1, N, 1 do
    local item = items[i] ---@type fml.types.ui.search.IItem
    if deleted_uuids[item.parent] then
      deleted_uuids[item.uuid] = true
    else
      items[k] = items[i]
      k = k + 1
    end
  end
  for i = k, N, 1 do
    items[i] = nil
  end

  if self._item_uuid_cur == uuid then
    lnum = math.max(1, math.min(lnum - 1, #items)) ---@type integer
    self._item_lnum_cur = lnum
    self._item_uuid_cur = items[lnum] and items[lnum].uuid or nil
  end

  vim.schedule(function()
    self.dirtier_main:mark_dirty()
    self.dirtier_preview:mark_dirty()
  end)
end

---@return nil
function M:mark_all_items_deleted()
  self.items = {}
  self._deleted_uuids = {}
  self._item_lnum_cur = 1
  self._item_uuid_cur = nil
  vim.schedule(function()
    self.dirtier_main:mark_dirty()
    self.dirtier_preview:mark_dirty()
  end)
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

---@return nil
function M:show_sate()
  eve.reporter.error({
    from = "fl.ui.search.state",
    subject = "show_state",
    details = {
      dirtier_dimension = self.dirtier_dimension:snapshot(),
      dirtier_data = self.dirtier_data:snapshot(),
      dirtier_main = self.dirtier_main:snapshot(),
      dirtier_preview = self.dirtier_preview:snapshot(),
      enable_multiline_input = self.enable_multiline_input,
      input = self.input:snapshot(),
      input_history = self.input_history and self.input_history:collect() or "nil",
      input_line_count = self.input_line_count:snapshot(),
      item_present_uuid = self.item_present_uuid or "nil",
      max_width = self.max_width,
      title = self.title,
      uuid = self.uuid,
      visible = self.visible:snapshot(),
    },
  })
end

return M
