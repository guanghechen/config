local __module_name__ = "eve.ux.search.context" ---@type string

---@class eve.ux.IRawSearchDimension
---@field public height                 ?number
---@field public max_width              ?number
---@field public max_height             ?number
---@field public row                    ?number
---@field public col                    ?number
---@field public width                  ?number
---@field public width_preview          ?number

---@class eve.ux.ISearchDimension
---@field public height                 ?number
---@field public max_width              number
---@field public max_height             number
---@field public row                    ?number
---@field public col                    ?number
---@field public width                  ?number
---@field public width_preview          ?number

---@class eve.ux.SearchContext
---@field protected _disposed           boolean
---@field protected _item_lnum_cur      integer
---@field protected _item_uuid_cur      string|nil
---@field protected _uuids_selected     table<string, true>
---
---@field public dirtier_dimension      std.collection.IDirtier
---@field public dirtier_data           std.collection.IDirtier
---@field public dirtier_data_cache     std.collection.IDirtier
---@field public dirtier_main           std.collection.IDirtier
---@field public dirtier_preview        std.collection.IDirtier
---@field public dirtier_selected       std.collection.IDirtier
---
---@field public flag_selected          std.collection.IObservable
---@field public input                  std.collection.IObservable
---@field public input_history          std.collection.IHistory|nil
---@field public input_line_count       std.collection.IObservable
---@field public state_has_matched      std.collection.IObservable
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
---@field public dimension              eve.ux.ISearchDimension
---@field public enable_multiline_input boolean
---@field public item_max_width         integer
---@field public item_uuid_present      string|nil
---@field public items                  eve.ux.search.IItem[]
---@field public items_valid_map        table<string, eve.ux.search.IItem>
---@field public items_original         eve.ux.search.IItem[]
---@field public multiple               boolean
---@field public permanent              boolean
---@field public uuid                   string
local M = {}
M.__index = M

---@class eve.ux.ISearchStateProps
---@field public delay_fetch            integer
---@field public dimension              eve.ux.IRawSearchDimension|nil
---@field public enable_multiline_input boolean
---@field public fetch_data             eve.ux.search.IFetchData
---@field public flag_selected          std.collection.IObservable
---@field public input                  std.collection.IObservable
---@field public input_history          std.collection.IHistory|nil
---@field public multiple               boolean|nil
---@field public permanent              boolean|nil
---@field public preview_title          string|nil
---@field public preview_wrap           boolean|nil
---@field public title                  string

---@param props                         eve.ux.ISearchStateProps
---@return eve.ux.SearchContext
function M.new(props)
  local self = setmetatable({}, M)

  local dirtier_dimension = std.Dirtier.new({ dirty = false }) ---@type std.collection.IDirtier
  local dirtier_data = std.Dirtier.new({ dirty = false }) ---@type std.collection.IDirtier
  local dirtier_data_cache = std.Dirtier.new({ dirty = false }) ---@type std.collection.IDirtier
  local dirtier_main = std.Dirtier.new({ dirty = false }) ---@type std.collection.IDirtier
  local dirtier_preview = std.Dirtier.new({ dirty = false }) ---@type std.collection.IDirtier
  local dirtier_selected = std.Dirtier.new({ dirty = false }) ---@type std.collection.IDirtier

  local flag_selected = props.flag_selected ---@type std.collection.IObservable
  local input = props.input ---@type std.collection.IObservable
  local input_history = props.input_history ---@type std.collection.IHistory|nil
  local input_line_count = std.Observable.from_value(eve.oxi.count_lines(input:snapshot())) ---@type std.collection.IObservable
  local state_has_matched = std.Observable.new({ value = false, equals = std.fn.falsy }) ---@type std.collection.IObservable

  local cfg_input_title = props.title ---@type string
  local cfg_preview_title = props.preview_title or " preview " ---@type string
  local cfg_preview_wrap = not not props.preview_wrap ---@type boolean

  local delay_fetch = props.delay_fetch ---@type integer
  local raw_dimension = props.dimension or {} ---@type eve.ux.IRawSearchDimension
  ---@type eve.ux.ISearchDimension
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
  local fetch_data = props.fetch_data ---@type eve.ux.search.IFetchData
  local multiple = not not props.multiple ---@type boolean
  local permanent = not not props.permanent ---@type boolean

  local uuid = eve.oxi.uuid() ---@type string

  ---@type std.collection.Scheduler
  local fetch_scheduler = std.Scheduler.new({
    name = string.format("%s | %s", uuid, __module_name__),
    mode = "throttle",
    delay = delay_fetch,
    timeout = 200000,
    silent = std.fn.falsy,
    value = std.Observable.from_value(true),
    task = function(_, _, callback)
      local input_cur = input:snapshot() ---@type string
      local force = dirtier_data_cache:is_dirty() ---@type boolean
      dirtier_data_cache:mark_clean()
      fetch_data(input_cur, force, function(succeed, data)
        if succeed and data ~= nil then
          local item_max_width = 0 ---@type integer
          ---@diagnostic disable-next-line: invisible
          local item_uuid_cursor = data.uuid_cursor or data.uuid_present or self._item_uuid_cur ---@type string|nil
          local item_uuid_present = data.uuid_present ---@type string|nil
          local next_item_lnum = 1 ---@type integer
          local next_items = data.items ---@type eve.ux.search.IItem[]
          local next_items_original = data.items ---@type eve.ux.search.IItem[]
          local next_items_valid_map = {} ---@type table<string, eve.ux.search.IItem>
          local next_uuids_selected = {} ---@type table<string, true>

          for _, item in ipairs(next_items_original) do
            local width = vim.api.nvim_strwidth(item.text) ---@type integer
            item_max_width = item_max_width < width and width or item_max_width ---@type integer
            next_items_valid_map[item.uuid] = item
          end

          ---@diagnostic disable-next-line: invisible
          for uuid_item in pairs(self._uuids_selected) do
            if next_items_valid_map[uuid_item] then
              next_uuids_selected[uuid_item] = true
            end
          end

          if flag_selected:snapshot() then
            next_items = {} ---@type eve.ux.search.IItem[]
            for _, item in ipairs(next_items_original) do
              if next_uuids_selected[item.uuid] then
                table.insert(next_items, item)
              end
            end
          end

          for lnum, item in ipairs(next_items) do
            if item.uuid == item_uuid_cursor then
              next_item_lnum = lnum
            end
          end

          self.item_uuid_present = item_uuid_present
          self.item_max_width = item_max_width
          self.items = next_items
          self.items_original = next_items_original
          self.items_valid_map = next_items_valid_map
          ---@diagnostic disable-next-line: invisible
          self._uuids_selected = next_uuids_selected
          self:locate(next_item_lnum)

          self.state_has_matched:next(#next_items > 0)
          self.dirtier_data:mark_clean()
          self.dirtier_main:mark_dirty()
          self.dirtier_preview:mark_dirty()
          self.dirtier_selected:mark_dirty()

          callback(true, true)
        else
          self.dirtier_data:mark_clean()
          callback(false, "")
        end
      end)
    end,
  })

  ---@return nil
  local function on_flag_selected_change()
    local items_original = self.items_original ---@type eve.ux.search.IItem[]
    local items = flag_selected:snapshot() and {} or items_original ---@type eve.ux.search.IItem[]

    if flag_selected:snapshot() then
      for _, item in ipairs(items_original) do
        ---@diagnostic disable-next-line: invisible
        if self._uuids_selected[item.uuid] then
          table.insert(items, item)
        end
      end
    end

    self.items = items
    self.state_has_matched:next(#items > 0)
    self.dirtier_main:mark_dirty()
    self.dirtier_selected:mark_dirty()

    ---@diagnostic disable-next-line: invisible
    local item_lnum_next = self:resolve_current_lnum(self._item_uuid_cur) or 1 ---@type integer
    self:locate(item_lnum_next)
  end

  ---@return nil
  local function on_input_change()
    if enable_multiline_input then
      local line_count = eve.oxi.count_lines(input:snapshot())
      input_line_count:next(line_count)
    end
    self.dirtier_data:mark_dirty()
  end

  ---@return nil
  local function on_refresh()
    local visible = self:isvisible() ---@type boolean
    local is_data_dirty = self.dirtier_data:is_dirty() ---@type boolean
    if visible and is_data_dirty then
      fetch_scheduler:schedule()
    end
  end

  ---@return nil
  local function on_data_cache_dirty()
    dirtier_selected:mark_dirty()
  end

  self._disposed = false
  self._item_lnum_cur = 0 ---@type integer
  self._item_uuid_cur = nil ---@type string|nil
  self._uuids_selected = {} ---@type table<string, true>
  self.dirtier_dimension = dirtier_dimension
  self.dirtier_data = dirtier_data
  self.dirtier_data_cache = dirtier_data_cache
  self.dirtier_main = dirtier_main
  self.dirtier_preview = dirtier_preview
  self.dirtier_selected = dirtier_selected

  self.flag_selected = flag_selected
  self.input = input
  self.input_history = input_history
  self.input_line_count = input_line_count
  self.state_has_matched = state_has_matched

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
  self.items = {} ---@type eve.ux.search.IItem[]
  self.items_original = {} ---@type eve.ux.search.IItem[]
  self.items_valid_map = {} ---@type table<string, eve.ux.search.IItem>
  self.multiple = multiple
  self.permanent = permanent
  self.uuid = uuid

  flag_selected:subscribe(std.Subscriber.new({ on_next = on_flag_selected_change }), false)
  input:subscribe(std.Subscriber.new({ on_next = on_input_change }), false)
  dirtier_data:subscribe(std.Subscriber.new({ on_next = on_refresh }), false)
  dirtier_data_cache:subscribe(std.Subscriber.new({ on_next = on_data_cache_dirty }), false)
  return self
end

---@return nil
function M:hide()
  if self._disposed then
    return
  end

  local winnr_input = self.winnr_input ---@type integer|nil
  local bufnr_input = self.bufnr_input ---@type integer|nil
  local winnr_main = self.winnr_main ---@type integer|nil
  local bufnr_main = self.bufnr_main ---@type integer|nil
  local winnr_preview = self.winnr_preview ---@type integer|nil
  local bufnr_preview = self.bufnr_preview ---@type integer|nil
  self.winnr_input = nil
  self.bufnr_input = nil
  self.winnr_main = nil
  self.bufnr_main = nil
  self.winnr_preview = nil
  self.bufnr_preview = nil
  eve.win.close(winnr_input)
  eve.buf.close(bufnr_input)
  eve.win.close(winnr_main)
  eve.buf.close(bufnr_main)
  eve.win.close(winnr_preview)
  eve.buf.close(bufnr_preview)
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true

  local winnr_input = self.winnr_input ---@type integer|nil
  local winnr_main = self.winnr_main ---@type integer|nil
  local winnr_preview = self.winnr_preview ---@type integer|nil
  self.winnr_input = nil
  self.winnr_main = nil
  self.winnr_preview = nil
  eve.win.close(winnr_input)
  eve.win.close(winnr_main)
  eve.win.close(winnr_preview)

  self.dirtier_dimension:dispose()
  self.dirtier_data:dispose()
  self.dirtier_main:dispose()
  self.dirtier_preview:dispose()
  self.dirtier_selected:dispose()
  self.state_has_matched:dispose()
  self.input_line_count:dispose()
end

---@return nil
function M:health()
  if self._disposed then
    local message = string.format("[%s#%s] already been disposed.", __module_name__, self.uuid) ---@type string
    error(message)
  end
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@return boolean
function M:isfocused()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  return winnr == self.winnr_input or winnr == self.winnr_main or winnr == self.winnr_preview
end

---@return boolean
function M:isvisible()
  local winnr_input = self.winnr_input ---@type integer|nil
  if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
    return true
  end

  local winnr_main = self.winnr_main ---@type integer|nil
  if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
    return true
  end

  local winnr_preview = self.winnr_preview ---@type integer|nil
  if winnr_preview ~= nil and vim.api.nvim_win_is_valid(winnr_preview) then
    return true
  end

  return false
end

---@param raw_dimension                 eve.ux.IRawSearchDimension
---@return nil
function M:change_dimension(raw_dimension)
  self:health()
  local old_dimension = self.dimension

  ---@type eve.ux.ISearchDimension
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
  self:health()
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
  self:health()
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
  self:health()
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
  self:health()
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
  self:health()
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

---@return eve.ux.search.IItem|nil
---@return integer
function M:get_current()
  self:health()
  local lnum = self._item_lnum_cur ---@type integer
  return self.items[lnum], lnum
end

---@return integer
function M:get_current_lnum()
  self:health()
  return self._item_lnum_cur
end

---@return string|nil
function M:get_current_uuid()
  self:health()
  return self._item_uuid_cur
end

---@return eve.ux.search.IItem[]
function M:get_selected_items()
  self:health()
  local selected = {} ---@type eve.ux.search.IItem[]
  local items_valid_map = self.items_valid_map ---@type table<string, eve.ux.search.IItem>
  for uuid in pairs(self._uuids_selected) do
    local item = items_valid_map[uuid] ---@type eve.ux.search.IItem|nil
    if item then
      table.insert(selected, item)
    end
  end
  return selected
end

---@param uuid                          string
---@return boolean
function M:has_item_deleted(uuid)
  self:health()
  return not self.items_valid_map[uuid]
end

---@param lnum                          integer
---@return integer
function M:locate(lnum)
  self:health()
  local items = self.items ---@type eve.ux.search.IItem[]
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
  self:health()
  self.items = {} ---@type eve.ux.search.IItem[]
  self.items_valid_map = {} ---@type table<string, eve.ux.search.IItem>
  self._uuids_selected = {} ---@type table<string, true>
  self._item_lnum_cur = 0 ---@type integer
  self._item_uuid_cur = nil ---@type string|nil
  vim.schedule(function()
    self.dirtier_main:mark_dirty()
    self.dirtier_preview:mark_dirty()
    self.dirtier_selected:mark_dirty()
    self.state_has_matched:next(false)
  end)
end

---@return integer
function M:moveup()
  self:health()
  local items = self.items ---@type eve.ux.search.IItem[]
  if #items <= 1 then
    return 0
  else
    local step = vim.v.count1 or 1 ---@type integer
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if winnr == self.winnr_main then
      local cursor = vim.api.nvim_win_get_cursor(winnr)
      local row = cursor[1] ---@type integer
      local lnum = std.fn.navigate_circular(row, -step, #items) ---@type integer
      return self:locate(lnum)
    else
      local lnum = std.fn.navigate_circular(self._item_lnum_cur, -step, #items) ---@type integer
      return self:locate(lnum)
    end
  end
end

---@return integer
function M:movedown()
  self:health()
  local items = self.items ---@type eve.ux.search.IItem[]
  if #items <= 1 then
    return 0
  else
    local step = vim.v.count1 or 1 ---@type integer
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if winnr == self.winnr_main then
      local cursor = vim.api.nvim_win_get_cursor(winnr)
      local row = cursor[1] ---@type integer
      local lnum = std.fn.navigate_circular(row, step, #items) ---@type integer
      return self:locate(lnum)
    else
      local lnum = std.fn.navigate_circular(self._item_lnum_cur, step, #items) ---@type integer
      return self:locate(lnum)
    end
  end
end

---@return integer|nil
function M:place_lnum_sign()
  self:health()
  local bufnr = self.bufnr_main ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.sign_unplace("", { buffer = bufnr, id = eve.var.sign.NR_SEARCH_MAIN_CURRENT })
    vim.fn.sign_unplace("", { buffer = bufnr, id = eve.var.sign.NR_SEARCH_MAIN_PRESENT })

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
          and eve.var.sign.SEARCH_MAIN_PRESENT_CUR
        or eve.var.sign.SEARCH_MAIN_PRESENT
      vim.fn.sign_place(
        eve.var.sign.NR_SEARCH_MAIN_PRESENT,
        "",
        sign,
        bufnr,
        { lnum = item_lnum_present, priority = 40 }
      )
    end

    if item_lnum_current > 0 then
      local uuid = self._item_uuid_cur ---@type string|nil
      local sign = (uuid ~= nil and self._uuids_selected[uuid]) ---
          and eve.var.sign.SEARCH_MAIN_SELECTED_CUR
        or eve.var.sign.SEARCH_MAIN_CURRENT
      vim.fn.sign_place(
        eve.var.sign.NR_SEARCH_MAIN_CURRENT,
        "",
        sign,
        bufnr,
        { lnum = item_lnum_current, priority = 30 }
      )
      return item_lnum_current
    end
  end
  return nil
end

---@return nil
function M:place_selected_sign()
  self:health()
  local bufnr = self.bufnr_main ---@type integer|nil
  if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
    vim.fn.sign_unplace(eve.var.sign.GROUP_SEARCH_MAIN_SELECTED, { buffer = bufnr })

    local selected = self._uuids_selected ---@type table<string, true>
    local items = self.items ---@type eve.ux.search.IItem[]
    for lnum, item in ipairs(items) do
      if selected[item.uuid] then
        vim.fn.sign_place(
          lnum,
          eve.var.sign.GROUP_SEARCH_MAIN_SELECTED,
          eve.var.sign.SEARCH_MAIN_SELECTED,
          bufnr,
          { lnum = lnum, priority = 10 }
        )
      end
    end
  end
end

---@return nil
function M:reset_selected_items()
  self:health()
  self._uuids_selected = {}
  self.dirtier_selected:mark_dirty()
end

---@param uuid                          string|nil
---@return integer|nil
function M:resolve_current_lnum(uuid)
  self:health()
  for lnum, item in ipairs(self.items) do
    if item.uuid == uuid then
      return lnum
    end
  end
  return nil
end

---@param uuid                          string
---@return nil
function M:set_item_deleted(uuid)
  self:health()
  local items_valid_map = self.items_valid_map ---@type table<string, eve.ux.search.IItem>
  if not items_valid_map[uuid] then
    return
  end

  local lnum = std.table.find_index(self.items, function(item)
    return item.uuid == uuid
  end)
  if lnum == nil then
    return
  end

  local uuids_selected = self._uuids_selected ---@type table<string, true>
  items_valid_map[uuid] = nil
  uuids_selected[uuid] = nil

  local items = self.items ---@type eve.ux.search.IItem[]
  local parent_cur = items[lnum].parent ---@type string|nil
  if parent_cur ~= nil and lnum > 1 and items[lnum - 1].uuid == parent_cur then
    if lnum == #items or items[lnum + 1].parent ~= parent_cur then
      lnum = lnum - 1
      items_valid_map[parent_cur] = nil
      uuids_selected[parent_cur] = nil
    end
  end

  local N = #items ---@type integer
  local k = lnum ---@type integer
  for i = lnum + 1, N, 1 do
    local item = items[i] ---@type eve.ux.search.IItem
    if item.parent == nil or items_valid_map[item.parent] then
      items_valid_map[item.uuid] = items[i] ---@type eve.ux.search.IItem
      items[k] = items[i]
      k = k + 1
    else
      items_valid_map[item.uuid] = nil
      uuids_selected[item.uuid] = nil
    end
  end
  for i = N, k, -1 do
    items[i] = nil
  end

  self:locate(lnum)
  self.dirtier_main:mark_dirty()
  self.dirtier_preview:mark_dirty()
  self.dirtier_selected:mark_dirty()
end

---@param uuid                          string
---@param selected                      boolean
---@return nil
function M:set_item_selected(uuid, selected)
  self:health()
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

---@param lnum                          integer
---@return nil
function M:toggle_item_selected(lnum)
  self:health()
  if self.multiple then
    local item = self.items[lnum] ---@type eve.ux.search.IItem
    if item ~= nil then
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
  self:health()
  if self.multiple then
    local uuids_selected = self._uuids_selected ---@type table<string, true>

    local dirty = false ---@type boolean
    local selected = false ---@type boolean
    for _, lnum in ipairs(lnums) do
      local item = self.items[lnum] ---@type eve.ux.search.IItem|nil
      if item ~= nil and uuids_selected[item.uuid] then
        selected = true
        break
      end
    end

    local value = selected == false and true or nil ---@type boolean|nil
    for _, lnum in ipairs(lnums) do
      local item = self.items[lnum] ---@type eve.ux.search.IItem|nil
      if item ~= nil then
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
