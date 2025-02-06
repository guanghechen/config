local __module_name__ = "fml.ux.search.context" ---@type string

local fn = require("eve.builtin.fn")
local oxi = require("eve.builtin.oxi")
local reporter = require("eve.builtin.reporter")
local Dirtier = require("eve.collection.dirtier")
local Observable = require("eve.collection.observable")
local Scheduler = require("eve.collection.scheduler")
local Subscriber = require("eve.collection.subscriber")
local signs = require("eve.constant.sign")

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
---@field public dirtier_selected       eve.collection.IDirtier
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
---@field public cfg_input_title        string
---@field public cfg_preview_title      string
---@field public cfg_preview_wrap       boolean
---
---@field public focused_pane           "input"|"main"|"preview"
---@field public focused_pane_left      "input"|"main"
---@field public focused_pane_right     "preview"
---
---@field public dimension              fml.ux.search.IDimension
---@field public enable_multiline_input boolean
---@field public item_max_width         integer
---@field public item_uuid_present      string|nil
---@field public items                  fml.ux.search.IItem[]
---@field public multiple               boolean
---@field public permanent              boolean
---@field public uuid                   string
---
---@field public focus_left             fun(self: fml.ux.search.IContext): nil
---@field public focus_right            fun(self: fml.ux.search.IContext): nil
---@field public focus_input            fun(self: fml.ux.search.IContext): nil
---@field public focus_main             fun(self: fml.ux.search.IContext): nil
---@field public focus_preview          fun(self: fml.ux.search.IContext): nil
---
---@field public change_dimension       fun(self: fml.ux.search.IContext, dimension: fml.ux.search.IRawDimension): nil
---@field public get_current            fun(self: fml.ux.search.IContext): fml.ux.search.IItem|nil, integer
---@field public get_current_lnum       fun(self: fml.ux.search.IContext): integer
---@field public get_current_uuid       fun(self: fml.ux.search.IContext): string|nil
---@field public get_selected_items     fun(self: fml.ux.search.IContext): fml.ux.search.IItem[]
---@field public has_item_deleted       fun(self: fml.ux.search.IContext, uuid: string): boolean
---@field public set_current            fun(self: fml.ux.search.IContext, lnum: integer): integer
---@field public locate                 fun(self: fml.ux.search.IContext, lnum: integer): integer
---@field public mark_all_items_deleted fun(self: fml.ux.search.IContext): nil
---@field public moveup                 fun(self: fml.ux.search.IContext): integer
---@field public movedown               fun(self: fml.ux.search.IContext): integer
---@field public place_lnum_sign        fun(self: fml.ux.search.IContext): integer|nil
---@field public place_selected_sign    fun(self: fml.ux.search.IContext): nil
---@field public reset_selected_items   fun(self: fml.ux.search.IContext): nil
---@field public set_item_deleted       fun(self: fml.ux.search.IContext, uuid: string): nil
---@field public set_item_selected      fun(self: fml.ux.search.IContext, uuid: string, selected: boolean): nil
---@field public show_state             fun(self: fml.ux.search.IContext): nil
---@field public toggle_item_selected   fun(self: fml.ux.search.IContext, lnum: integer): nil
---@field public toggle_items_selected  fun(self: fml.ux.search.IContext, lnums: integer[]): nil

---@class fml.ux.search.Context : fml.ux.search.IContext
---@field protected _item_lnum_cur      integer
---@field protected _item_uuid_cur      string|nil
---@field protected _uuids_deleted      table<string, true>
---@field protected _uuids_selected     table<string, true>
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
  local dirtier_selected = Dirtier.new({ dirty = false }) ---@type eve.collection.IDirtier

  local input = props.input ---@type eve.collection.IObservable
  local input_history = props.input_history ---@type eve.collection.IHistory|nil
  local input_line_count = Observable.from_value(oxi.count_lines(input:snapshot())) ---@type eve.collection.IObservable
  local state_has_matched = Observable.new({ value = false, equals = fn.falsy }) ---@type eve.collection.IObservable
  local status = Observable.from_value("hidden")

  local cfg_input_title = props.title ---@type string
  local cfg_preview_title = props.preview_title or " preview " ---@type string
  local cfg_preview_wrap = not not props.preview_wrap ---@type boolean

  local delay_fetch = props.delay_fetch ---@type integer
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
  local enable_multiline_input = props.enable_multiline_input ---@type boolean
  local fetch_data = props.fetch_data ---@type fml.ux.search.IFetchData
  local multiple = not not props.multiple ---@type boolean
  local permanent = not not props.permanent ---@type boolean

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
          ---@diagnostic disable-next-line: invisible
          local item_lnum_next = self._item_lnum_cur or 1 ---@type integer
          local item_max_width = 0 ---@type integer
          ---@diagnostic disable-next-line: invisible
          local item_uuid_cursor = data.uuid_cursor or data.uuid_present or self._item_uuid_cur ---@type string|nil
          local item_uuid_present = data.uuid_present ---@type string|nil
          local items = data.items ---@type fml.ux.search.IItem[]

          for lnum, item in ipairs(items) do
            local width = vim.api.nvim_strwidth(item.text) ---@type integer
            item_max_width = item_max_width < width and width or item_max_width ---@type integer

            if item.uuid == item_uuid_cursor then
              item_lnum_next = lnum
            end
          end

          self.item_uuid_present = item_uuid_present
          self.items = items
          self.item_max_width = item_max_width
          self:locate(item_lnum_next)

          local uuids_selected = {} ---@type table<string, true>
          for _, item in ipairs(items) do
            ---@diagnostic disable-next-line: invisible
            if self._uuids_selected[item.uuid] then
              uuids_selected[item.uuid] = true
            end
          end

          ---@diagnostic disable-next-line: invisible
          self._uuids_deleted = {} ---@type table<string, true>
          ---@diagnostic disable-next-line: invisible
          self._uuids_selected = uuids_selected ---@type table<string, true>
          self.state_has_matched:next(#data.items > 0)

          self.dirtier_data:mark_clean()
          self.dirtier_main:mark_dirty()
          self.dirtier_preview:mark_dirty()
          self.dirtier_selected:mark_dirty()

          callback("fulfilled")
        else
          self.dirtier_data:mark_clean()
          callback("rejected", nil, data)
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
  self.dirtier_selected = dirtier_selected

  self.input = input
  self.input_history = input_history
  self.input_line_count = input_line_count
  self.state_has_matched = state_has_matched
  self.status = status

  self.cfg_input_title = cfg_input_title
  self.cfg_preview_title = cfg_preview_title
  self.cfg_preview_wrap = cfg_preview_wrap

  self.focused_pane = "input"
  self.focused_pane_left = "input"
  self.focused_pane_right = "preview"

  self.dimension = dimension
  self.enable_multiline_input = enable_multiline_input
  self.item_max_width = 0
  self.item_uuid_present = nil
  self.items = {}
  self.multiple = multiple
  self.permanent = permanent
  self.uuid = uuid

  self._item_lnum_cur = 0 ---@type integer
  self._item_uuid_cur = nil ---@type string|nil
  self._uuids_deleted = {} ---@type table<string, true>
  self._uuids_selected = {} ---@type table<string, true>

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
  self.dirtier_selected:dispose()
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

---@return nil
function M:focus_left()
  local pane = self.focused_pane_left ---@type string
  local winnr_pane = self["winnr_" .. pane] ---@type integer|nil
  if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
    self.focused_pane = pane
    local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
    if winnr ~= winnr_pane then
      vim.api.nvim_tabpage_set_win(0, winnr_pane)
    end
  end
end

---@return nil
function M:focus_right()
  local pane = self.focused_pane_right ---@type string
  local winnr_pane = self["winnr_" .. pane] ---@type integer|nil
  if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
    self.focused_pane = pane
    local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
    if winnr ~= winnr_pane then
      vim.api.nvim_tabpage_set_win(0, winnr_pane)
    end
  end
end

---@return nil
function M:focus_input()
  local winnr_pane = self.winnr_input ---@type integer|nil
  if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
    self.focused_pane = "input"
    self.focused_pane_left = "input"
    local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
    if winnr ~= winnr_pane then
      vim.api.nvim_tabpage_set_win(0, winnr_pane)
    end
  end
end

---@return nil
function M:focus_main()
  local winnr_pane = self.winnr_main ---@type integer|nil
  if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
    self.focused_pane = "main"
    self.focused_pane_left = "main"
    local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
    if winnr ~= winnr_pane then
      vim.api.nvim_tabpage_set_win(0, winnr_pane)
    end
  end
end

---@return nil
function M:focus_preview()
  local winnr_pane = self.winnr_preview ---@type integer|nil
  if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
    self.focused_pane = "preview"
    self.focused_pane_right = "preview"
    local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
    if winnr ~= winnr_pane then
      vim.api.nvim_tabpage_set_win(0, winnr_pane)
    end
  end
end

---@return fml.ux.search.IItem|nil
---@return integer
function M:get_current()
  local lnum = self._item_lnum_cur ---@type integer
  return self.items[lnum], lnum
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
  local uuids_selected = self._uuids_selected ---@type table<string, true>
  for _, item in ipairs(self.items) do
    if uuids_selected[item.uuid] then
      table.insert(selected, item)
    end
  end
  return selected
end

---@param uuid                          string
---@return boolean
function M:has_item_deleted(uuid)
  return self._uuids_deleted[uuid] == true
end

---@param lnum                          integer
---@return integer
function M:locate(lnum)
  local items = self.items ---@type fml.ux.search.IItem[]
  local item_lnum_next = math.max(1, math.min(#items, lnum)) ---@type integer
  local item_uuid_next = items[item_lnum_next] and items[item_lnum_next].uuid or nil ---@type string|nil
  if self._item_lnum_cur ~= item_lnum_next or self._item_uuid_cur ~= item_uuid_next then
    self.dirtier_preview:mark_dirty()
  end

  self._item_lnum_cur = item_lnum_next
  self._item_uuid_cur = item_uuid_next
  return item_lnum_next
end

---@return nil
function M:mark_all_items_deleted()
  self.items = {}
  self._uuids_deleted = {}
  self._uuids_selected = {}
  self._item_lnum_cur = 0
  self._item_uuid_cur = nil
  vim.schedule(function()
    self.dirtier_main:mark_dirty()
    self.dirtier_preview:mark_dirty()
    self.dirtier_selected:mark_dirty()
    self.state_has_matched:next(false)
  end)
end

---@return integer
function M:moveup()
  local items = self.items ---@type fml.ux.search.IItem[]
  if #items <= 1 then
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
  if #items <= 1 then
    return 0
  else
    local step = vim.v.count1 or 1 ---@type integer
    local lnum = fn.navigate_circular(self._item_lnum_cur, step, #items) ---@type integer
    return self:locate(lnum)
  end
end

---@return integer|nil
function M:place_lnum_sign()
  local bufnr = self.bufnr_main ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.sign_unplace("", { buffer = bufnr, id = signs.NR_SEARCH_MAIN_CURRENT })
    vim.fn.sign_unplace("", { buffer = bufnr, id = signs.NR_SEARCH_MAIN_PRESENT })

    local item_lnum_present = 0 ---@type integer
    do
      local item_uuid_present = self.item_uuid_present ---@type string|nil
      if item_uuid_present ~= nil then
        for lnum, item in ipairs(self.items) do
          if item.uuid == item_uuid_present then
            item_lnum_present = lnum
            break
          end
        end
      end
    end

    local item_lnum_current = 0 ---@type integer
    do
      local uuid = self._item_uuid_cur ---@type string|nil
      if uuid ~= nil then
        local lnum = self._item_lnum_cur ---@type integer
        local linecount = vim.api.nvim_buf_line_count(bufnr) ---@type integer
        if linecount > 0 and lnum > 0 and lnum <= linecount then
          item_lnum_current = lnum
        end
      end
    end

    if item_lnum_present > 0 then
      local sign = item_lnum_present == item_lnum_current ---
          and signs.SEARCH_MAIN_PRESENT_CUR
        or signs.SEARCH_MAIN_PRESENT
      vim.fn.sign_place(signs.NR_SEARCH_MAIN_PRESENT, "", sign, bufnr, { lnum = item_lnum_present, priority = 40 })
    end

    if item_lnum_current > 0 then
      local uuid = self._item_uuid_cur ---@type string|nil
      local sign = (uuid ~= nil and self._uuids_selected[uuid]) ---
          and signs.SEARCH_MAIN_SELECTED_CUR
        or signs.SEARCH_MAIN_CURRENT
      vim.fn.sign_place(signs.NR_SEARCH_MAIN_CURRENT, "", sign, bufnr, { lnum = item_lnum_current, priority = 30 })
      return item_lnum_current
    end
  end
  return nil
end

---@return nil
function M:place_selected_sign()
  local bufnr = self.bufnr_main ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.sign_unplace(signs.GROUP_SEARCH_MAIN_SELECTED, { buffer = bufnr })

    local selected = self._uuids_selected ---@type table<string, true>
    local items = self.items ---@type fml.ux.search.IItem[]
    for lnum, item in ipairs(items) do
      if selected[item.uuid] then
        vim.fn.sign_place(
          lnum,
          signs.GROUP_SEARCH_MAIN_SELECTED,
          signs.SEARCH_MAIN_SELECTED,
          bufnr,
          { lnum = lnum, priority = 10 }
        )
      end
    end
  end
end

---@return nil
function M:reset_selected_items()
  self._uuids_selected = {}
  self.dirtier_selected:mark_dirty()
end

---@param uuid                          string
---@return nil
function M:set_item_deleted(uuid)
  local deleted_uuids = self._uuids_deleted ---@type table<string, true>
  local uuids_selected = self._uuids_selected ---@type table<string, true>
  if deleted_uuids[uuid] then
    return
  end

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
  uuids_selected[uuid] = nil

  local parent_cur = items[lnum].parent ---@type string|nil
  if parent_cur ~= nil and lnum > 1 and items[lnum - 1].uuid == parent_cur then
    if lnum == #items or items[lnum + 1].parent ~= parent_cur then
      lnum = lnum - 1
      deleted_uuids[parent_cur] = true
      uuids_selected[parent_cur] = nil
    end
  end

  local k = lnum ---@type integer
  local N = #items ---@type integer
  for i = lnum + 1, N, 1 do
    local item = items[i] ---@type fml.ux.search.IItem
    if deleted_uuids[item.parent] then
      deleted_uuids[item.uuid] = true
      uuids_selected[item.uuid] = nil
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
    self.dirtier_selected:mark_dirty()
  end)
end

---@param uuid                          string
---@param selected                      boolean
---@return nil
function M:set_item_selected(uuid, selected)
  local selected_prev = self._uuids_selected[uuid] == true ---@type boolean
  if selected_prev ~= selected then
    if selected then
      self._uuids_selected[uuid] = true
    else
      self._uuids_selected[uuid] = nil
    end
    self.dirtier_selected:mark_dirty()
  end
end

---@return nil
function M:show_state()
  reporter.error({
    from = __module_name__,
    subject = "show_state",
    details = {
      cfg = {
        bufnr_input = self.bufnr_input or vim.NIL,
        bufnr_main = self.bufnr_main or vim.NIL,
        bufnr_preview = self.bufnr_preview or vim.NIL,
        winnr_input = self.winnr_input or vim.NIL,
        winnr_main = self.winnr_main or vim.NIL,
        winnr_preview = self.winnr_preview or vim.NIL,
        preview_title = self.cfg_preview_title,
        preview_wrap = self.cfg_preview_wrap,
      },

      dirtier = {
        dimension = self.dirtier_dimension:snapshot(),
        data = self.dirtier_data:snapshot(),
        data_cache = self.dirtier_data_cache:snapshot(),
        main = self.dirtier_main:snapshot(),
        preview = self.dirtier_preview:snapshot(),
        selected = self.dirtier_selected:snapshot(),
      },

      input = {
        keyword = self.input:snapshot(),
        history = self.input_history and self.input_history:collect() or vim.NIL,
        line_count = self.input_line_count:snapshot(),
      },

      state = {
        has_matched = self.state_has_matched:snapshot(),
        status = self.status:snapshot(),
      },

      focused_pane = self.focused_pane,
      focused_pane_left = self.focused_pane_left,
      focused_pane_right = self.focused_pane_right,

      dimension = self.dimension,
      enable_multiline_input = self.enable_multiline_input,
      item_uuid_present = self.item_uuid_present or vim.NIL,
      max_width = self.item_max_width,
      multiple = self.multiple,
      permanent = self.permanent,
      title = self.cfg_input_title,
      uuid = self.uuid,
    },
  })
end

---@param lnum                          integer
---@return nil
function M:toggle_item_selected(lnum)
  if self.multiple then
    local item = self.items[lnum] ---@type fml.ux.search.IItem
    if item ~= nil and not self._uuids_deleted[item.uuid] then
      local uuids_selected = self._uuids_selected ---@type table<string, true>
      if uuids_selected[item.uuid] then
        uuids_selected[item.uuid] = nil
      else
        uuids_selected[item.uuid] = true
      end
      self.dirtier_selected:mark_dirty()
    end
  end
end

---@param lnums                         integer[]
---@return nil
function M:toggle_items_selected(lnums)
  if self.multiple then
    local uuids_deleted = self._uuids_deleted ---@type table<string, true>
    local uuids_selected = self._uuids_selected ---@type table<string, true>

    local dirty = false ---@type boolean
    local selected = false ---@type boolean
    for _, lnum in ipairs(lnums) do
      local item = self.items[lnum] ---@type fml.ux.search.IItem|nil
      if item ~= nil and not uuids_deleted[item.uuid] then
        if uuids_selected[item.uuid] then
          selected = true
          break
        end
      end
    end

    local value = selected == false and true or nil ---@type boolean|nil
    for _, lnum in ipairs(lnums) do
      local item = self.items[lnum] ---@type fml.ux.search.IItem|nil
      if item ~= nil and not uuids_deleted[item.uuid] then
        dirty = true
        uuids_selected[item.uuid] = value
      end
    end
    if dirty then
      self.dirtier_selected:mark_dirty()
    end
  end
end

return M
