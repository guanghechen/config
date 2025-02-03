local __module_name__ = "fml.ux.search.context" ---@type string

local fn = require("eve.builtin.fn")
local oxi = require("eve.builtin.oxi")
local reporter = require("eve.builtin.reporter")
local Dirtier = require("eve.collection.dirtier")
local Observable = require("eve.collection.observable")
local Scheduler = require("eve.collection.scheduler")
local Subscriber = require("eve.collection.subscriber")

---@class fml.ux.search.IRawDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public row                    ?number
---@field public col                    ?number
---@field public width                  ?number
---@field public width_preview          ?number

---@class fml.ux.search.IDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public row                    ?number
---@field public col                    ?number
---@field public width                  ?number
---@field public width_preview          ?number

---@class fml.ux.search.IContext
---@field public dirtier_dimension      eve.collection.IDirtier
---@field public dirtier_data           eve.collection.IDirtier
---@field public dirtier_data_cache     eve.collection.IDirtier
---@field public dirtier_main           eve.collection.IDirtier
---@field public dirtier_preview        eve.collection.IDirtier
---
---@field public input                  eve.collection.IObservable
---@field public input_history          eve.collection.IHistory|nil
---@field public input_line_count       eve.collection.IObservable
---@field public state_has_matched      eve.collection.IObservable
---@field public status                 eve.collection.IObservable
---
---@field public bufnr_input            integer|nil
---@field public bufnr_main             integer|nil
---@field public bufnr_preview          integer|nil
---@field public winnr_input            integer|nil
---@field public winnr_main             integer|nil
---@field public winnr_preview          integer|nil
---
---@field public cfg_preview_title      string
---@field public cfg_preview_wrap       boolean
---
---@field public focused_pane           "input"|"main"|"preview"
---@field public focused_pane_left      "input"|"main"
---@field public focused_pane_right     "preview"
---
---@field public dimension              fml.ux.search.IDimension
---@field public enable_multiline_input boolean
---@field public item_present_uuid      string|nil
---@field public items                  fml.ux.search.IItem[]
---@field public max_width              integer
---@field public multiple               boolean
---@field public permanent              boolean
---@field public title                  string
---@field public uuid                   string
---
---@field public change_dimension       fun(self: fml.ux.search.IContext, dimension: fml.ux.search.IRawDimension): nil
---@field public get_current            fun(self: fml.ux.search.IContext): fml.ux.search.IItem|nil
---@field public get_current_lnum       fun(self: fml.ux.search.IContext): integer
---@field public get_current_uuid       fun(self: fml.ux.search.IContext): string|nil
---@field public get_selected_items     fun(self: fml.ux.search.IContext): fml.ux.search.IItem[]
---@field public has_item_deleted       fun(self: fml.ux.search.IContext, uuid: string): boolean
---@field public set_current            fun(self: fml.ux.search.IContext, lnum: integer): integer
---@field public locate                 fun(self: fml.ux.search.IContext, lnum: integer): integer
---@field public mark_item_deleted      fun(self: fml.ux.search.IContext, uuid: string): nil
---@field public mark_all_items_deleted fun(self: fml.ux.search.IContext): nil
---@field public moveup                 fun(self: fml.ux.search.IContext): integer
---@field public movedown               fun(self: fml.ux.search.IContext): integer
---@field public reset_selected_items   fun(self: fml.ux.search.IContext): nil
---@field public show_state             fun(self: fml.ux.search.IContext): nil
---@field public toggle_item_selected   fun(self: fml.ux.search.IContext, uuid: string): nil

---@class fml.ux.search.Context : fml.ux.search.IContext
---@field protected _deleted_uuids      table<string, boolean>
---@field protected _item_lnum_cur      integer
---@field protected _item_uuid_cur      string|nil
---@field protected _selected_items     table<string, true>
local M = {}
M.__index = M

---@class fml.ux.search.state.IProps
---@field public delay_fetch            integer
---@field public dimension              fml.ux.search.IRawDimension|nil
---@field public enable_multiline_input boolean
---@field public fetch_data             fml.ux.search.IFetchData
---@field public input                  eve.collection.IObservable
---@field public input_history          eve.collection.IHistory|nil
---@field public multiple               boolean|nil
---@field public permanent              boolean|nil
---@field public preview_title          string|nil
---@field public preview_wrap           boolean|nil
---@field public title                  string

---@param props                         fml.ux.search.state.IProps
---@return fml.ux.search.Context
function M.new(props)
  local self = setmetatable({}, M)

  local dirtier_dimension = Dirtier.new({ dirty = false }) ---@type eve.collection.IDirtier
  local dirtier_data = Dirtier.new({ dirty = false }) ---@type eve.collection.IDirtier
  local dirtier_data_cache = Dirtier.new({ dirty = false }) ---@type eve.collection.IDirtier
  local dirtier_main = Dirtier.new({ dirty = false }) ---@type eve.collection.IDirtier
  local dirtier_preview = Dirtier.new({ dirty = false }) ---@type eve.collection.IDirtier
  local state_has_matched = Observable.new({ value = false, equals = fn.falsy }) ---@type eve.collection.IObservable
  local status = Observable.from_value("hidden")

  local raw_dimension = props.dimension or {} ---@type fml.ux.search.IRawDimension
  ---@type fml.ux.search.IDimension
  local dimension = {
    height = raw_dimension.height,
    max_width = raw_dimension.max_width or 0.8,
    max_height = raw_dimension.max_height or 0.8,
    row = raw_dimension.row,
    col = raw_dimension.col,
    width = raw_dimension.width,
    width_preview = raw_dimension.width_preview,
  }

  local delay_fetch = props.delay_fetch ---@type integer
  local enable_multiline_input = props.enable_multiline_input ---@type boolean
  local fetch_data = props.fetch_data ---@type fml.ux.search.IFetchData
  local input = props.input ---@type eve.collection.IObservable
  local input_history = props.input_history ---@type eve.collection.IHistory|nil
  local input_line_count = Observable.from_value(oxi.count_lines(input:snapshot())) ---@type eve.collection.IObservable
  local multiple = not not props.multiple ---@type boolean
  local permanent = not not props.permanent ---@type boolean
  local title = props.title ---@type string
  local cfg_preview_title = props.preview_title or " preview " ---@type string
  local cfg_preview_wrap = not not props.preview_wrap ---@type boolean

  local uuid = oxi.uuid() ---@type string

  ---@type eve.collection.IScheduler
  local fetch_scheduler = Scheduler.new({
    name = "fml.ux.search.state.fetch",
    delay = delay_fetch,
    task = function(callback)
      local input_cur = input:snapshot() ---@type string
      local force = dirtier_data_cache:is_dirty() ---@type boolean
      dirtier_data_cache:mark_clean()
      fetch_data(input_cur, force, function(succeed, data)
        if succeed and data ~= nil then
          local max_width = 0 ---@type integer
          local item_lnum_next = 1 ---@type integer
          local items = data.items ---@type fml.ux.search.IItem[]
          local present_uuid = data.present_uuid ---@type string|nil
          local cursor_uuid = data.cursor_uuid or data.present_uuid ---@type string|nil

          ---@diagnostic disable-next-line: invisible
          local item_uuid_cur = cursor_uuid or self._item_uuid_cur ---@type string|nil
          for lnum, item in ipairs(items) do
            local width = vim.api.nvim_strwidth(item.text) ---@type integer
            max_width = max_width < width and width or max_width

            if item.uuid == item_uuid_cur then
              item_lnum_next = lnum
            end
          end

          self.item_present_uuid = present_uuid
          self.items = items
          self.max_width = max_width
          self:locate(item_lnum_next)
          callback("fulfilled")
        else
          callback("rejected", nil, data)
        end

        self.dirtier_data:mark_clean()
        if succeed and data ~= nil then
          ---@diagnostic disable-next-line: invisible
          self._deleted_uuids = {} ---@type table<string, boolean>
          self.dirtier_main:mark_dirty()
          self.dirtier_preview:mark_dirty()
          self.state_has_matched:next(#data.items > 0)
        end
      end)
    end,
  })

  ---@return nil
  local function on_input_change()
    if enable_multiline_input then
      local line_count = oxi.count_lines(input:snapshot())
      input_line_count:next(line_count)
    end
    self.dirtier_data:mark_dirty()
  end

  ---@return nil
  local function on_refresh()
    local _status = status:snapshot() ---@type eve.e.WidgetStatus
    local visible = _status == "visible" ---@type boolean
    local is_data_dirty = self.dirtier_data:is_dirty() ---@type boolean
    if visible and is_data_dirty then
      fetch_scheduler:schedule()
    end
  end

  self.dirtier_dimension = dirtier_dimension
  self.dirtier_data = dirtier_data
  self.dirtier_data_cache = dirtier_data_cache
  self.dirtier_main = dirtier_main
  self.dirtier_preview = dirtier_preview

  self.input = input
  self.input_history = input_history
  self.input_line_count = input_line_count
  self.state_has_matched = state_has_matched
  self.status = status

  self.focused_pane = "input"
  self.focused_pane_left = "input"
  self.focused_pane_right = "preview"

  self.dimension = dimension
  self.enable_multiline_input = enable_multiline_input
  self.item_present_uuid = nil
  self.items = {} ---@type fml.ux.search.IItem[]
  self.max_width = 0 ---@type integer
  self.multiple = multiple
  self.permanent = permanent
  self.title = title
  self.cfg_preview_title = cfg_preview_title
  self.cfg_preview_wrap = cfg_preview_wrap
  self.uuid = uuid
  self._deleted_uuids = {} ---@type table<string, boolean>
  self._item_lnum_cur = 1 ---@type integer
  self._item_uuid_cur = nil ---@type string|nil
  self._selected_items = {} ---@type table<string, true>

  input:subscribe(Subscriber.new({ on_next = on_input_change }), false)
  status:subscribe(Subscriber.new({ on_next = on_refresh }), false)
  dirtier_data:subscribe(Subscriber.new({ on_next = on_refresh }), false)
  return self
end

---@return nil
function M:dispose()
  self.dirtier_dimension:dispose()
  self.dirtier_data:dispose()
  self.dirtier_main:dispose()
  self.dirtier_preview:dispose()
  self.state_has_matched:dispose()
  self.input_line_count:dispose()
  self.status:dispose()
end

---@param raw_dimension                 fml.ux.search.IRawDimension
---@return nil
function M:change_dimension(raw_dimension)
  local old_dimension = self.dimension

  ---@type fml.ux.search.IDimension
  local dimension = {
    height = raw_dimension.height,
    max_width = raw_dimension.max_width or 0.8,
    max_height = raw_dimension.max_height or 0.8,
    row = raw_dimension.row,
    col = raw_dimension.col,
    width = raw_dimension.width,
    width_preview = raw_dimension.width_preview,
  }
  self.dimension = dimension

  if
    dimension.height ~= old_dimension.height
    or dimension.max_width ~= old_dimension.max_width
    or dimension.max_height ~= old_dimension.max_height
    or dimension.width ~= old_dimension.width
    or dimension.width_preview ~= old_dimension.width_preview
  then
    self.dirtier_dimension:mark_dirty()
  end
end

---@return fml.ux.search.IItem|nil
function M:get_current()
  local lnum = self._item_lnum_cur ---@type integer
  return self.items[lnum]
end

---@return integer
function M:get_current_lnum()
  return self._item_lnum_cur
end

---@return string|nil
function M:get_current_uuid()
  return self._item_uuid_cur
end

---@return fml.ux.search.IItem[]
function M:get_selected_items()
  local selected = {} ---@type fml.ux.search.IItem[]
  local items = self.items ---@type fml.ux.search.IItem[]
  for uuid in pairs(self._selected_items) do
    local item = items[uuid] ---@type fml.ux.search.IItem|nil
    if item ~= nil then
      table.insert(selected, item)
    end
  end
  return selected
end

---@param uuid                          string
---@return boolean
function M:has_item_deleted(uuid)
  return self._deleted_uuids[uuid] ~= nil
end

---@param lnum                          integer
---@return integer
function M:locate(lnum)
  local items = self.items ---@type fml.ux.search.IItem[]
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
  local items = self.items ---@type fml.ux.search.IItem[]

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
    local item = items[i] ---@type fml.ux.search.IItem
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
    lnum = math.max(1, math.min(lnum, #items)) ---@type integer
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
    self.state_has_matched:next(false)
  end)
end

---@return integer
function M:moveup()
  local items = self.items ---@type fml.ux.search.IItem[]
  if #items < 1 then
    return 0
  else
    local step = vim.v.count1 or 1 ---@type integer
    local lnum = fn.navigate_circular(self._item_lnum_cur, -step, #items) ---@type integer
    return self:locate(lnum)
  end
end

---@return integer
function M:movedown()
  local items = self.items ---@type fml.ux.search.IItem[]
  if #items < 1 then
    return 0
  else
    local step = vim.v.count1 or 1 ---@type integer
    local lnum = fn.navigate_circular(self._item_lnum_cur, step, #items) ---@type integer
    return self:locate(lnum)
  end
end

---@return nil
function M:reset_selected_items()
  self._selected_items = {}
  -- TODO: update signcolumn
end

---@return nil
function M:show_sate()
  reporter.error({
    from = __module_name__,
    subject = "show_state",
    details = {
      dirtier_dimension = self.dirtier_dimension:snapshot(),
      dirtier_data = self.dirtier_data:snapshot(),
      dirtier_main = self.dirtier_main:snapshot(),
      dirtier_preview = self.dirtier_preview:snapshot(),
      has_matched = self.state_has_matched:snapshot(),
      enable_multiline_input = self.enable_multiline_input,
      input = self.input:snapshot(),
      input_history = self.input_history and self.input_history:collect() or vim.NIL,
      input_line_count = self.input_line_count:snapshot(),
      item_present_uuid = self.item_present_uuid or vim.NIL,
      max_width = self.max_width,
      status = self.status:snapshot(),
      title = self.title,
      uuid = self.uuid,
    },
  })
end

---@param uuid                          string
---@return nil
function M:toggle_item_selected(uuid)
  local selected_items = self._selected_items ---@type table<string, true>
  local item = self.items[self._item_lnum_cur] ---@type fml.ux.search.IItem
  if item == nil or selected_items[uuid] ~= nil then
    return
  end

  if self.multiple then
    if selected_items[uuid] then
      selected_items[uuid] = nil
    else
      selected_items[uuid] = true
    end

    -- TODO: update signcolumn
  end
end

return M
