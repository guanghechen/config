local __module_name__ = "fml.ux.select" ---@type string

local oxi = require("eve.builtin.oxi")
local reporter = require("eve.builtin.reporter")
local Observable = require("eve.collection.observable")
local icons = require("eve.constant.icon")

local state = require("eve.state")
local Search = require("fml.ux.search.search")
local SearchContext = require("fml.ux.search.context")

---@class fml.ux.ISelect : eve.t.ux.IWidget
---@field public change_dimension       fun(self: fml.ux.ISelect, dimension: fml.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.ux.ISelect, title: string): nil
---@field public change_preview_title   fun(self: fml.ux.ISelect, title: string): nil
---@field public get_item               fun(self: fml.ux.ISelect, uuid: string): fml.ux.select.IItem|nil
---@field public get_item_selected      fun(self: fml.ux.ISelect): fml.ux.select.IItem|nil, integer, string|nil
---@field public get_matched_items      fun(self: fml.ux.ISelect): fml.ux.select.IMatchedItem[]
---@field public get_winnr_input        fun(self: fml.ux.ISelect): integer|nil
---@field public get_winnr_main         fun(self: fml.ux.ISelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.ux.ISelect): integer|nil
---@field public mark_data_dirty        fun(self: fml.ux.ISelect): nil
---@field public mark_item_deleted      fun(self: fml.ux.ISelect, uuid: string): nil
---@field public show                   fun(self: fml.ux.ISelect): nil
---@field public toggle                 fun(self: fml.ux.ISelect): nil

---@alias fml.ux.select.IFetchData
---| fun(force: boolean): fml.ux.select.IData

---@alias fml.ux.select.IFetchPreviewData
---| fun(item: fml.ux.select.IItem): fml.ux.search.preview.IData|nil

---@alias fml.ux.select.IPatchPreviewData
---| fun(item: fml.ux.select.IItem, last_item: fml.ux.select.IItem, last_data: fml.ux.search.preview.IData): fml.ux.search.preview.IData

---@alias fml.ux.select.IMatchedItemCmp
---| fun(item1: fml.ux.select.IMatchedItem, item2: fml.ux.select.IMatchedItem): boolean

---@alias fml.ux.select.IRenderItem
---| fun(item: fml.ux.select.IItem, match: fml.ux.select.IMatchedItem): string, eve.t.IHighlightInline[]

---@alias fml.ux.select.IOnConfirm
---| fun(widget: fml.ux.ISelect, items: fml.ux.select.IItem[]): nil

---@class fml.ux.select.IData
---@field public items                  fml.ux.select.IItem[]
---@field public uuid_cursor            ?string
---@field public uuid_present           ?string

---@class fml.ux.select.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string|nil
---@field public data                   any|nil

---@class fml.ux.select.IMatchedItem
---@field public order                  integer
---@field public uuid                   string
---@field public score                  integer
---@field public matches                eve.t.IMatchPoint[]

---@class fml.ux.select.IProvider
---@field public fetch_data             fml.ux.select.IFetchData
---@field public fetch_preview_data     ?fml.ux.select.IFetchPreviewData
---@field public patch_preview_data     ?fml.ux.select.IPatchPreviewData
---@field public render_item            ?fml.ux.select.IRenderItem

---@class fml.ux.Select : fml.ux.ISelect
---@field protected _case_sensitive     eve.collection.IObservable
---@field protected _cmp                fml.ux.select.IMatchedItemCmp|nil
---@field protected _flag_fuzzy         eve.collection.IObservable
---@field protected _flag_regex         eve.collection.IObservable
---@field protected _frecency           eve.collection.IFrecency|nil
---@field protected _full_matches       fml.ux.select.IMatchedItem[]
---@field protected _item_map           table<string, fml.ux.select.IItem>
---@field protected _item_uuid_cursor   string|nil
---@field protected _item_uuid_present  string|nil
---@field protected _last_case_sensitive boolean
---@field protected _last_input         string|nil
---@field protected _live_data_dirty    eve.collection.IObservable
---@field protected _matches            fml.ux.select.IMatchedItem[]
---@field protected _provider           fml.ux.select.IProvider
---@field protected _search             fml.ux.search.ISearch
local M = {}
M.__index = M

---@class fml.ux.select.IProps
---@field public case_sensitive         ?eve.collection.IObservable
---@field public cmp                    ?fml.ux.select.IMatchedItemCmp
---@field public delay_fetch            ?integer
---@field public delay_render           ?integer
---@field public dimension              ?fml.ux.search.IRawDimension
---@field public dirty_on_invisible     ?boolean
---@field public preview_enabled        boolean
---@field public preview_title          ?string
---@field public preview_wrap           ?boolean
---@field public extend_preset_keymaps  ?boolean
---@field public flag_fuzzy             ?eve.collection.IObservable
---@field public flag_selected          ?eve.collection.IObservable
---@field public flag_regex             ?eve.collection.IObservable
---@field public frecency               ?eve.collection.IFrecency
---@field public input                  ?eve.collection.IObservable
---@field public input_history          ?eve.collection.IHistory
---@field public input_keymaps          ?eve.t.IKeymap[]
---@field public main_keymaps           ?eve.t.IKeymap[]
---@field public multiple               ?boolean
---@field public permanent              ?boolean
---@field public preview_keymaps        ?eve.t.IKeymap[]
---@field public provider               fml.ux.select.IProvider
---@field public statusline_items       ?eve.t.ux.widget.IRawStatuslineItem[]
---@field public title                  string
---@field public on_close               ?fml.ux.search.IOnClose
---@field public on_confirm             fml.ux.select.IOnConfirm
---@field public on_invisible           ?fml.ux.search.IOnInvisible
---@field public on_preview_rendered    ?fml.ux.search.IOnPreviewRendered

---@param props                         fml.ux.select.IProps
---@return fml.ux.Select
function M.new(props)
  local self = setmetatable({}, M)

  local delay_fetch = props.delay_fetch or 128 ---@type integer
  local dimension = props.dimension ---@type fml.ux.search.IRawDimension|nil
  local flag_fuzzy = props.flag_fuzzy or Observable.from_value(false) ---@type eve.collection.IObservable
  local flag_regex = props.flag_regex or Observable.from_value(false) ---@type eve.collection.IObservable
  local flag_selected = props.flag_selected or Observable.from_value(false) ---@type eve.collection.IObservable
  local input = props.input or Observable.from_value("") ---@type eve.collection.IObservable
  local input_history = props.input_history ---@type eve.collection.IHistory|nil
  local multiple = props.multiple ---@type boolean|nil
  local permanent = props.permanent ---@type boolean|nil
  local preview_title = props.preview_title ---@type string|nil
  local preview_wrap = props.preview_wrap ---@type boolean|nil
  local title = props.title ---@type string

  ---@param input_text                  string
  ---@param force                       boolean
  ---@param callback                    fml.ux.search.IFetchDataCallback
  ---@return nil
  local function fetch_data(input_text, force, callback)
    vim.schedule(function()
      local ok, data = pcall(self.fetch_data, self, input_text, force)
      callback(ok, data)
    end)
  end

  ---@type fml.ux.search.IContext
  local context = SearchContext.new({
    delay_fetch = delay_fetch,
    dimension = dimension,
    enable_multiline_input = false,
    fetch_data = fetch_data,
    flag_selected = flag_selected,
    input = input,
    input_history = input_history,
    multiple = multiple,
    permanent = permanent,
    preview_title = preview_title,
    preview_wrap = preview_wrap,
    title = title,
  })

  local case_sensitive = props.case_sensitive or Observable.from_value(false) ---@type eve.collection.IObservable
  local cmp = props.cmp ---@type fml.ux.select.IMatchedItemCmp|nil
  local delay_render = props.delay_render or 48 ---@type integer
  local dirty_on_invisible = not not props.dirty_on_invisible ---@type boolean
  local preview_enabled = props.preview_enabled ---@type boolean
  local extend_preset_keymaps = not not props.extend_preset_keymaps ---@type boolean
  local frecency = props.frecency ---@type eve.collection.IFrecency|nil
  local input_keymaps = props.input_keymaps ---@type eve.t.IKeymap[]|nil
  local live_data_dirty = Observable.from_value(true) ---@type eve.collection.IObservable
  local main_keymaps = props.main_keymaps ---@type eve.t.IKeymap[]|nil
  local preview_keymaps = props.preview_keymaps ---@type eve.t.IKeymap[]|nil
  local provider = props.provider ---@type fml.ux.select.IProvider
  local statusline_items = props.statusline_items ---@type eve.t.ux.widget.IRawStatuslineItem[]
  local on_confirm_from_props = props.on_confirm ---@type fml.ux.select.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.ux.search.IOnClose|nil
  local on_invisible_from_props = props.on_invisible ---@type fml.ux.search.IOnInvisible|nil
  local on_preview_rendered = props.on_preview_rendered ---@type fml.ux.search.IOnPreviewRendered|nil

  if statusline_items == nil or extend_preset_keymaps then
    ---@return nil
    local function toggle_case_sensitive()
      local flag = case_sensitive:snapshot() ---@type boolean
      case_sensitive:next(not flag)
      self:mark_search_state_dirty()
      state.status.dirtier_statusline:mark_dirty()
    end

    ---@return nil
    local function toggle_flag_fuzzy()
      local flag = flag_fuzzy:snapshot() ---@type boolean
      flag_fuzzy:next(not flag)
      self:mark_search_state_dirty()
      state.status.dirtier_statusline:mark_dirty()
    end

    ---@return nil
    local function toggle_flag_regex()
      local flag = flag_regex:snapshot() ---@type boolean
      flag_regex:next(not flag)
      self:mark_search_state_dirty()
      state.status.dirtier_statusline:mark_dirty()
    end

    ---@return nil
    local function toggle_flag_selected()
      local flag = flag_selected:snapshot() ---@type boolean
      flag_selected:next(not flag)
      self:mark_search_state_dirty()
      state.status.dirtier_statusline:mark_dirty()
    end

    ---@type eve.t.ux.widget.IRawStatuslineItem[]
    statusline_items = vim.list_extend(statusline_items or {}, {
      {
        disabled = not multiple,
        type = "flag",
        desc = "select: toggle selected",
        symbol = icons.symbols.flag_selected,
        state = flag_selected,
        callback = toggle_flag_selected,
      },
      {
        type = "flag",
        desc = "select: toggle flag fuzzy",
        symbol = icons.symbols.flag_fuzzy,
        state = flag_fuzzy,
        callback = toggle_flag_fuzzy,
      },
      {
        type = "flag",
        desc = "select: toggle case sensitive",
        symbol = icons.symbols.flag_case_sensitive,
        state = case_sensitive,
        callback = toggle_case_sensitive,
      },
      {
        type = "flag",
        desc = "select: toggle flag regex",
        symbol = icons.symbols.flag_regex,
        state = flag_regex,
        callback = toggle_flag_regex,
      },
    })

    ---@type eve.t.IKeymap[]
    local preset_keymaps = {
      {
        modes = { "n", "v" },
        key = "<leader>ti",
        callback = toggle_case_sensitive,
        desc = "select: toggle case sensitive",
      },
      {
        modes = { "n", "v" },
        key = "<leader>tr",
        callback = toggle_flag_regex,
        desc = "select: toggle flag regex",
      },
    }

    input_keymaps = vim.list_extend(vim.list_slice(preset_keymaps), input_keymaps or {})
    main_keymaps = vim.list_extend(vim.list_slice(preset_keymaps), main_keymaps or {})
    preview_keymaps = vim.list_extend(vim.list_slice(preset_keymaps), preview_keymaps or {})
  end ---@type fml.ux.search.IFetchPreviewData|nil

  local fetch_preview_data = nil
  if preview_enabled and provider.fetch_preview_data ~= nil then
    fetch_preview_data = function(item)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type fml.ux.select.IItem|nil
      return select_item ~= nil and provider.fetch_preview_data(select_item) or nil
    end
  end

  ---@type fml.ux.search.IPatchPreviewData|nil
  local patch_preview_data = nil
  if preview_enabled and provider.patch_preview_data ~= nil then
    patch_preview_data = function(item, last_item, data)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type fml.ux.select.IItem
      ---@diagnostic disable-next-line: invisible
      local last_select_item = self._item_map[last_item.uuid] ---@type fml.ux.select.IItem
      return provider.patch_preview_data(select_item, last_select_item, data)
    end
  end

  ---@param widget                      fml.ux.search.ISearch
  ---@param items                       fml.ux.search.IItem[]
  ---@return nil
  ---@diagnostic disable-next-line: unused-local
  local function on_confirm(widget, items)
    local select_items = {} ---@type fml.ux.select.IItem[]
    for _, item in ipairs(items) do
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type fml.ux.select.IItem
      table.insert(select_items, select_item)
    end

    if #select_items < 1 then
      reporter.error({
        from = __module_name__,
        subject = "select: on_confirm",
        message = "no items selected",
        details = { title = title, items = items, count = #select_items },
      })
      return
    end

    if #select_items > 1 and not context.multiple then
      reporter.error({
        from = __module_name__,
        subject = "select: on_confirm",
        message = "More than one items selected, but `multiple` is not enabled",
        details = { title = title, items = items, count = #select_items },
      })
      return
    end

    if frecency ~= nil then
      for _, item in ipairs(items) do
        frecency:access(item.uuid)
      end
    end
    on_confirm_from_props(self, select_items)
  end

  ---@return nil
  local function on_invisible()
    if dirty_on_invisible then
      self:mark_data_dirty()
    end

    if on_invisible_from_props ~= nil then
      on_invisible_from_props()
    end
  end

  ---@type fml.ux.search.ISearch
  local search = Search.new({
    context = context,
    delay_render = delay_render,
    fetch_preview_data = fetch_preview_data,
    input_keymaps = input_keymaps,
    main_keymaps = main_keymaps,
    patch_preview_data = patch_preview_data,
    preview_keymaps = preview_keymaps,
    statusline_items = statusline_items,
    on_confirm = on_confirm,
    on_close = on_close_from_props,
    on_invisible = on_invisible,
    on_preview_rendered = on_preview_rendered,
  })

  self._case_sensitive = case_sensitive
  self._cmp = cmp
  self._flag_fuzzy = flag_fuzzy
  self._flag_regex = flag_regex
  self._frecency = frecency
  self._full_matches = {}
  self._item_map = {}
  self._item_uuid_cursor = nil
  self._item_uuid_present = nil
  self._last_input = nil ---@type string|nil
  self._last_case_sensitive = case_sensitive:snapshot()
  self._live_data_dirty = live_data_dirty
  self._matches = {}
  self._provider = provider
  self._search = search
  return self
end

---@param dimension                     fml.ux.search.IRawDimension
---@return nil
function M:change_dimension(dimension)
  self._search.context:change_dimension(dimension)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  self._search:change_input_title(title)
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  self._search:change_preview_title(title)
end

---@return nil
function M:close()
  self._search:close()
end

---@param item1                         fml.ux.select.IMatchedItem
---@param item2                         fml.ux.select.IMatchedItem
---@return boolean
function M.cmp_by_score(item1, item2)
  return item1.score == item2.score and item1.order < item2.order or item1.score > item2.score
end

---@param item                          fml.ux.select.IItem
---@param match                         fml.ux.select.IMatchedItem
---@return string
---@return eve.t.IHighlightInline[]
function M.default_render_item(item, match)
  local highlights = {} ---@type eve.t.IHighlightInline[]
  for _, piece in ipairs(match.matches) do
    ---@type eve.t.IHighlightInline[]
    local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return item.text, highlights
end

---@param input                         string
---@param force                         boolean
---@return fml.ux.search.IData
function M:fetch_data(input, force)
  local is_data_dirty = force or self._live_data_dirty:snapshot() ---@type boolean
  self._live_data_dirty:next(false)

  if is_data_dirty then
    local frecency = self._frecency ---@type eve.collection.IFrecency|nil
    local data = self._provider.fetch_data(force) ---@type fml.ux.select.IData
    local item_map = {} ---@type table<string, fml.ux.select.IItem>
    local full_matches = {} ---@type fml.ux.select.IMatchedItem[]
    for order, item in ipairs(data.items) do
      local score = frecency ~= nil and frecency:score(item.uuid) or 0 ---@type integer
      local match_item = { order = order, uuid = item.uuid, score = score, matches = {} } ---@type fml.ux.select.IMatchedItem
      item_map[item.uuid] = item
      table.insert(full_matches, match_item)
    end

    if self._cmp then
      table.sort(full_matches, self._cmp)
    end

    self._item_uuid_cursor = data.uuid_cursor
    self._item_uuid_present = data.uuid_present
    self._item_map = item_map
    self._full_matches = full_matches
    self._matches = full_matches
  end

  local item_map = self._item_map ---@type table<string, fml.ux.select.IItem>
  local matches = self:filter(input) ---@type fml.ux.select.IMatchedItem[]
  local items = {} ---@type fml.ux.search.IItem[]
  local render_item = self._provider.render_item or M.default_render_item ---@type fml.ux.select.IRenderItem
  for _, match in ipairs(matches) do
    local item = item_map[match.uuid] ---@type fml.ux.select.IItem
    local line, highlights = render_item(item, match)
    ---@type fml.ux.search.IItem
    local search_item = { group = item.group, uuid = item.uuid, text = line, highlights = highlights }
    table.insert(items, search_item)
  end

  ---@type fml.ux.search.IData
  return { items = items, uuid_cursor = self._item_uuid_cursor, uuid_present = self._item_uuid_present }
end

---@param input                         string
---@return fml.ux.select.IMatchedItem[]
function M:filter(input)
  local frecency = self._frecency ---@type eve.collection.IFrecency|nil
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean

  local matches = self._full_matches ---@type fml.ux.select.IMatchedItem[]
  if #input < 1 then
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = frecency:score(uuid)
      end
    end
  else
    local old_matches = self._full_matches ---@type fml.ux.select.IMatchedItem[]
    local last_case_sensitive = self._last_case_sensitive ---@type boolean
    local last_input = self._last_input ---@type string|nil
    if last_input ~= nil and case_sensitive == last_case_sensitive or not last_case_sensitive then
      if not last_case_sensitive then
        local last_input_lower = last_input ~= nil and last_input:lower() or nil ---@type string|nil
        local input_lower = input:lower() ---@type string
        if
          last_input_lower ~= nil
          and #input_lower > #last_input_lower
          and input_lower:sub(1, #last_input_lower) == last_input_lower
        then
          old_matches = self._matches
        end
      else
        if last_input ~= nil and #input > #last_input and input:sub(1, #last_input) == last_input then
          old_matches = self._matches
        end
      end
    end

    ---@type fml.ux.select.IMatchedItem[]
    matches = self:find_matched_items(input, old_matches)
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = match.score + frecency:score(uuid)
      end
    end
  end

  if self._cmp then
    table.sort(matches, self._cmp)
  end

  self._last_case_sensitive = case_sensitive
  self._last_input = input
  self._matches = matches
  return matches
end

---@param input                         string
---@param old_matches                   fml.ux.select.IMatchedItem[]
---@return fml.ux.select.IMatchedItem[]
function M:find_matched_items(input, old_matches)
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean
  local flag_fuzzy = self._flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self._flag_regex:snapshot() ---@type boolean
  local item_map = self._item_map ---@type table<string, fml.ux.select.IItem>

  local lines = {} ---@type string[]
  if case_sensitive then
    for _, match in ipairs(old_matches) do
      local uuid = match.uuid ---@type string
      local text = item_map[uuid].text ---@type string
      table.insert(lines, text)
    end
  else
    input = input:lower()
    for _, match in ipairs(old_matches) do
      local uuid = match.uuid ---@type string
      local item = item_map[uuid] ---@type fml.ux.select.IItem|nil
      if item ~= nil then
        item.text_lower = item.text_lower or item.text:lower()
        table.insert(lines, item.text_lower)
      end
    end
  end

  ---@type eve.builtin.oxi.string.ILineMatch[]|nil
  local oxi_matches = oxi.find_match_points_line_by_line(input, lines, flag_fuzzy, flag_regex)
  if oxi_matches == nil then
    return old_matches
  end

  local matches = {} ---@type fml.ux.select.IMatchedItem[]
  for _, oxi_match in ipairs(oxi_matches) do
    local old_match = old_matches[oxi_match.lnum] ---@type fml.ux.select.IMatchedItem

    ---@type fml.ux.select.IMatchedItem
    local match = {
      order = old_match.order,
      uuid = old_match.uuid,
      score = oxi_match.score,
      matches = oxi_match.matches,
    }
    table.insert(matches, match)
  end
  return matches
end

---@return boolean
function M:focused()
  return self._search:focused()
end

---@return nil
function M:focus()
  self._search:focus()
end

---@param uuid                          string
---@return                              fml.ux.select.IItem|nil
function M:get_item(uuid)
  return self._item_map[uuid]
end

---@return fml.ux.select.IItem|nil
---@return integer
function M:get_item_selected()
  local _, lnum, uuid = self._search:get_item_selected() ---@type fml.ux.search.IItem|nil, integer, string|nil
  local item = uuid ~= nil and self._item_map[uuid] or nil ---@type fml.ux.select.IItem|nil
  return item, lnum
end

---@return                              fml.ux.select.IMatchedItem[]
function M:get_matched_items()
  return self._matches
end

---@return integer|nil
function M:get_winnr_main()
  return self._search.context.winnr_main
end

---@return integer|nil
function M:get_winnr_input()
  return self._search.context.winnr_input
end

---@return integer|nil
function M:get_winnr_preview()
  return self._search.context.winnr_preview
end

---@return nil
function M:hide()
  self._search:hide()
end

---@return nil
function M:mark_data_dirty()
  self._live_data_dirty:next(true)
  self._search.context.dirtier_data:mark_dirty()
end

---@param uuid                          string
---@return nil
function M:mark_item_deleted(uuid)
  self._search:mark_item_deleted(uuid)
end

---@return nil
function M:mark_search_state_dirty()
  self._search.context.dirtier_data:mark_dirty()
end

---@return nil
function M:show()
  self._search:show()
end

---@return nil
function M:toggle()
  self._search:toggle()
end

return M
