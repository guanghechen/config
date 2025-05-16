local __module_name__ = "eve.ux.select" ---@type string

---@class eve.ux.ISelect : std.t.ux.IWidget
---@field public context                eve.ux.SearchContext
---@field public change_dimension       fun(self: eve.ux.ISelect, dimension: eve.ux.IRawSearchDimension): nil
---@field public change_input_title     fun(self: eve.ux.ISelect, title: string): nil
---@field public change_preview_title   fun(self: eve.ux.ISelect, title: string): nil
---@field public get_item               fun(self: eve.ux.ISelect, uuid: string): eve.ux.select.IItem|nil
---@field public get_item_selected      fun(self: eve.ux.ISelect): eve.ux.select.IItem|nil, integer, string|nil
---@field public get_matched_items      fun(self: eve.ux.ISelect): std.t.IScoredMatch[]
---@field public get_winnr_input        fun(self: eve.ux.ISelect): integer|nil
---@field public get_winnr_main         fun(self: eve.ux.ISelect): integer|nil
---@field public get_winnr_preview      fun(self: eve.ux.ISelect): integer|nil
---@field public mark_data_dirty        fun(self: eve.ux.ISelect): nil
---@field public mark_item_deleted      fun(self: eve.ux.ISelect, uuid: string): nil
---@field public reset_input            fun(self: eve.ux.ISelect, text: string): nil
---@field public toggle                 fun(self: eve.ux.ISelect): nil

---@alias eve.ux.select.IFetchData
---| fun(force: boolean): eve.ux.select.IData

---@alias eve.ux.select.IFetchPreviewData
---| fun(item: eve.ux.select.IItem): eve.ux.ISearchPreviewData|nil

---@alias eve.ux.select.IPatchPreviewData
---| fun(item: eve.ux.select.IItem, last_item: eve.ux.select.IItem, last_data: eve.ux.ISearchPreviewData): eve.ux.ISearchPreviewData

---@alias eve.ux.select.IMatchedItemCmp
---| fun(item1: std.t.IScoredMatch, item2: std.t.IScoredMatch): boolean

---@alias eve.ux.select.IRenderItem
---| fun(item: eve.ux.select.IItem, match: std.t.IScoredMatch): string, std.t.IHighlightInline[]

---@alias eve.ux.select.IOnConfirm
---| fun(widget: eve.ux.ISelect, items: eve.ux.select.IItem[]): nil

---@class eve.ux.select.IData
---@field public items                  eve.ux.select.IItem[]
---@field public uuid_cursor            ?string
---@field public uuid_present           ?string

---@class eve.ux.select.IItem
---@field public group                  string|nil
---@field public uuid                   string
---@field public text                   string
---@field public text_lower             string|nil
---@field public data                   any|nil

---@class eve.ux.select.IProvider
---@field public fetch_data             eve.ux.select.IFetchData
---@field public fetch_preview_data     ?eve.ux.select.IFetchPreviewData
---@field public patch_preview_data     ?eve.ux.select.IPatchPreviewData
---@field public render_item            ?eve.ux.select.IRenderItem

---@class eve.ux.Select : eve.ux.ISelect
---@field protected _case_sensitive     std.collection.IObservable
---@field protected _cmp                eve.ux.select.IMatchedItemCmp|nil
---@field protected _flag_fuzzy         std.collection.IObservable
---@field protected _flag_regex         std.collection.IObservable
---@field protected _frecency           std.collection.IFrecency|nil
---@field protected _full_matches       std.t.IScoredMatch[]
---@field protected _item_map           table<string, eve.ux.select.IItem>
---@field protected _item_uuid_cursor   string|nil
---@field protected _item_uuid_present  string|nil
---@field protected _last_case_sensitive boolean
---@field protected _last_input         string|nil
---@field protected _live_data_dirty    std.collection.IObservable
---@field protected _matches            std.t.IScoredMatch[]
---@field protected _provider           eve.ux.select.IProvider
---@field protected _search             eve.ux.ISearch
local M = {}
M.__index = M

---@class eve.ux.select.IProps
---@field public case_sensitive         ?std.collection.IObservable
---@field public cmp                    ?eve.ux.select.IMatchedItemCmp
---@field public delay_fetch            ?integer
---@field public delay_render           ?integer
---@field public dimension              ?eve.ux.IRawSearchDimension
---@field public dirty_on_invisible     ?boolean
---@field public preview_enabled        boolean
---@field public preview_title          ?string
---@field public preview_wrap           ?boolean
---@field public extend_preset_keymaps  ?boolean
---@field public flag_fuzzy             ?std.collection.IObservable
---@field public flag_selected          ?std.collection.IObservable
---@field public flag_regex             ?std.collection.IObservable
---@field public frecency               ?std.collection.IFrecency
---@field public input                  ?std.collection.IObservable
---@field public input_history          ?std.collection.IHistory
---@field public input_keymaps          ?std.t.IKeymap[]
---@field public main_keymaps           ?std.t.IKeymap[]
---@field public multiple               ?boolean
---@field public permanent              ?boolean
---@field public preview_keymaps        ?std.t.IKeymap[]
---@field public provider               eve.ux.select.IProvider
---@field public statusline_items       ?std.t.ux.widget.IRawStatuslineItem[]
---@field public title                  string
---@field public on_close               ?eve.ux.search.IOnClose
---@field public on_confirm             eve.ux.select.IOnConfirm
---@field public on_invisible           ?eve.ux.search.IOnInvisible
---@field public on_preview_rendered    ?eve.ux.search.IOnPreviewRendered

---@param props                         eve.ux.select.IProps
---@return eve.ux.Select
function M.new(props)
  local self = setmetatable({}, M)

  local delay_fetch = props.delay_fetch or 128 ---@type integer
  local dimension = props.dimension ---@type eve.ux.IRawSearchDimension|nil
  local flag_fuzzy = props.flag_fuzzy or std.Observable.from_value(false) ---@type std.collection.IObservable
  local flag_regex = props.flag_regex or std.Observable.from_value(false) ---@type std.collection.IObservable
  local flag_selected = props.flag_selected or std.Observable.from_value(false) ---@type std.collection.IObservable
  local input = props.input or std.Observable.from_value("") ---@type std.collection.IObservable
  local input_history = props.input_history ---@type std.collection.IHistory|nil
  local multiple = props.multiple ---@type boolean|nil
  local permanent = props.permanent ---@type boolean|nil
  local preview_title = props.preview_title ---@type string|nil
  local preview_wrap = props.preview_wrap ---@type boolean|nil
  local title = props.title ---@type string

  ---@param input_text                  string
  ---@param force                       boolean
  ---@param callback                    eve.ux.search.IFetchDataCallback
  ---@return nil
  local function fetch_data(input_text, force, callback)
    vim.schedule(function()
      local ok, data = pcall(self.fetch_data, self, input_text, force)
      callback(ok, data)
    end)
  end

  ---@type eve.ux.SearchContext
  local context = eve.ux.SearchContext.new({
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

  local case_sensitive = props.case_sensitive or std.Observable.from_value(false) ---@type std.collection.IObservable
  local cmp = props.cmp ---@type eve.ux.select.IMatchedItemCmp|nil
  local delay_render = props.delay_render or 48 ---@type integer
  local dirty_on_invisible = not not props.dirty_on_invisible ---@type boolean
  local preview_enabled = props.preview_enabled ---@type boolean
  local extend_preset_keymaps = not not props.extend_preset_keymaps ---@type boolean
  local frecency = props.frecency ---@type std.collection.IFrecency|nil
  local input_keymaps = props.input_keymaps ---@type std.t.IKeymap[]|nil
  local live_data_dirty = std.Observable.from_value(true) ---@type std.collection.IObservable
  local main_keymaps = props.main_keymaps ---@type std.t.IKeymap[]|nil
  local preview_keymaps = props.preview_keymaps ---@type std.t.IKeymap[]|nil
  local provider = props.provider ---@type eve.ux.select.IProvider
  local statusline_items = props.statusline_items ---@type std.t.ux.widget.IRawStatuslineItem[]
  local on_confirm_from_props = props.on_confirm ---@type eve.ux.select.IOnConfirm
  local on_close_from_props = props.on_close ---@type eve.ux.search.IOnClose|nil
  local on_invisible_from_props = props.on_invisible ---@type eve.ux.search.IOnInvisible|nil
  local on_preview_rendered = props.on_preview_rendered ---@type eve.ux.search.IOnPreviewRendered|nil

  if statusline_items == nil or extend_preset_keymaps then
    ---@return nil
    local function toggle_case_sensitive()
      local flag = case_sensitive:snapshot() ---@type boolean
      case_sensitive:next(not flag)
      self:mark_search_state_dirty()
      eve.status.dirtier_statusline:mark_dirty()
    end

    ---@return nil
    local function toggle_flag_fuzzy()
      local flag = flag_fuzzy:snapshot() ---@type boolean
      flag_fuzzy:next(not flag)
      self:mark_search_state_dirty()
      eve.status.dirtier_statusline:mark_dirty()
    end

    ---@return nil
    local function toggle_flag_regex()
      local flag = flag_regex:snapshot() ---@type boolean
      flag_regex:next(not flag)
      self:mark_search_state_dirty()
      eve.status.dirtier_statusline:mark_dirty()
    end

    ---@return nil
    local function toggle_flag_selected()
      local flag = flag_selected:snapshot() ---@type boolean
      flag_selected:next(not flag)
      -- self:mark_search_state_dirty() -- toggle selected state should not mark the data dirty
      eve.status.dirtier_statusline:mark_dirty()
    end

    ---@type std.t.ux.widget.IRawStatuslineItem[]
    statusline_items = vim.list_extend(statusline_items or {}, {
      {
        disabled = not multiple,
        type = "flag",
        desc = "select: toggle selected",
        symbol = eve.icon.symbols.flag_selected,
        state = flag_selected,
        callback = toggle_flag_selected,
      },
      {
        type = "flag",
        desc = "select: toggle flag fuzzy",
        symbol = eve.icon.symbols.flag_fuzzy,
        state = flag_fuzzy,
        callback = toggle_flag_fuzzy,
      },
      {
        type = "flag",
        desc = "select: toggle case sensitive",
        symbol = eve.icon.symbols.flag_case_sensitive,
        state = case_sensitive,
        callback = toggle_case_sensitive,
      },
      {
        type = "flag",
        desc = "select: toggle flag regex",
        symbol = eve.icon.symbols.flag_regex,
        state = flag_regex,
        callback = toggle_flag_regex,
      },
    })

    ---@type std.t.IKeymap[]
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
  end ---@type eve.ux.search.IFetchPreviewData|nil

  local fetch_preview_data = nil
  if preview_enabled and provider.fetch_preview_data ~= nil then
    fetch_preview_data = function(item)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type eve.ux.select.IItem|nil
      return select_item ~= nil and provider.fetch_preview_data(select_item) or nil
    end
  end

  ---@type eve.ux.search.IPatchPreviewData|nil
  local patch_preview_data = nil
  if preview_enabled and provider.patch_preview_data ~= nil then
    patch_preview_data = function(item, last_item, data)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type eve.ux.select.IItem
      ---@diagnostic disable-next-line: invisible
      local last_select_item = self._item_map[last_item.uuid] ---@type eve.ux.select.IItem
      return provider.patch_preview_data(select_item, last_select_item, data)
    end
  end

  ---@param widget                      eve.ux.ISearch
  ---@param items                       eve.ux.search.IItem[]
  ---@return nil
  ---@diagnostic disable-next-line: unused-local
  local function on_confirm(widget, items)
    local select_items = {} ---@type eve.ux.select.IItem[]
    for _, item in ipairs(items) do
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type eve.ux.select.IItem
      table.insert(select_items, select_item)
    end

    if #select_items < 1 then
      std.reporter.error({
        from = __module_name__,
        subject = "select: on_confirm",
        message = "no items selected",
        details = { title = title, items = items, count = #select_items },
      })
      return
    end

    if #select_items > 1 and not context.multiple then
      std.reporter.error({
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

  ---@type eve.ux.ISearch
  local search = eve.ux.Search.new({
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
  self.context = search.context
  return self
end

---@param dimension                     eve.ux.IRawSearchDimension
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

---@param item1                         std.t.IScoredMatch
---@param item2                         std.t.IScoredMatch
---@return boolean
function M.cmp_by_score(item1, item2)
  return item1.score == item2.score and item1.order < item2.order or item1.score > item2.score
end

---@param item                          eve.ux.select.IItem
---@param match                         std.t.IScoredMatch
---@return string
---@return std.t.IHighlightInline[]
function M.default_render_item(item, match)
  local highlights = {} ---@type std.t.IHighlightInline[]
  for _, piece in ipairs(match.matches) do
    ---@type std.t.IHighlightInline[]
    local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return item.text, highlights
end

---@param input                         string
---@param force                         boolean
---@return eve.ux.search.IData
function M:fetch_data(input, force)
  local is_data_dirty = force or self._live_data_dirty:snapshot() ---@type boolean
  self._live_data_dirty:next(false)

  if is_data_dirty then
    local frecency = self._frecency ---@type std.collection.IFrecency|nil
    local data = self._provider.fetch_data(force) ---@type eve.ux.select.IData
    local item_map = {} ---@type table<string, eve.ux.select.IItem>
    local full_matches = {} ---@type std.t.IScoredMatch[]
    for order, item in ipairs(data.items) do
      local score = frecency ~= nil and frecency:score(item.uuid) or 0 ---@type integer
      local match_item = { order = order, uuid = item.uuid, score = score, matches = {} } ---@type std.t.IScoredMatch
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

  local item_map = self._item_map ---@type table<string, eve.ux.select.IItem>
  local matches = self:filter(input) ---@type std.t.IScoredMatch[]
  local items = {} ---@type eve.ux.search.IItem[]
  local render_item = self._provider.render_item or M.default_render_item ---@type eve.ux.select.IRenderItem
  for _, match in ipairs(matches) do
    local item = item_map[match.uuid] ---@type eve.ux.select.IItem
    local line, highlights = render_item(item, match)
    ---@type eve.ux.search.IItem
    local search_item = { group = item.group, uuid = item.uuid, text = line, highlights = highlights }
    table.insert(items, search_item)
  end

  ---@type eve.ux.search.IData
  return { items = items, uuid_cursor = self._item_uuid_cursor, uuid_present = self._item_uuid_present }
end

---@param input                         string
---@return std.t.IScoredMatch[]
function M:filter(input)
  local frecency = self._frecency ---@type std.collection.IFrecency|nil
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean

  local matches = self._full_matches ---@type std.t.IScoredMatch[]
  if #input < 1 then
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = frecency:score(uuid)
      end
    end
  else
    local old_matches = self._full_matches ---@type std.t.IScoredMatch[]
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

    ---@type std.t.IScoredMatch[]
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
---@param old_matches                   std.t.IScoredMatch[]
---@return std.t.IScoredMatch[]
function M:find_matched_items(input, old_matches)
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean
  local flag_fuzzy = self._flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self._flag_regex:snapshot() ---@type boolean
  local item_map = self._item_map ---@type table<string, eve.ux.select.IItem>

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
      local item = item_map[uuid] ---@type eve.ux.select.IItem|nil
      if item ~= nil then
        item.text_lower = item.text_lower or item.text:lower()
        table.insert(lines, item.text_lower)
      end
    end
  end

  ---@type eve.builtin.oxi.string.ILineMatch[]|nil
  local oxi_matches = eve.oxi.find_match_points_line_by_line(input, lines, flag_fuzzy, flag_regex)
  if oxi_matches == nil then
    return old_matches
  end

  local matches = {} ---@type std.t.IScoredMatch[]
  for _, oxi_match in ipairs(oxi_matches) do
    local old_match = old_matches[oxi_match.lnum] ---@type std.t.IScoredMatch

    ---@type std.t.IScoredMatch
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

---@return nil
function M:focus()
  self._search:focus()
end

---@return boolean
function M:isdisposed()
  return self._search:isdisposed()
end

---@return nil
function M:hide()
  return self._search:hide()
end

---@return boolean
function M:isfocused()
  return self._search:isfocused()
end

---@return boolean
function M:isvisible()
  return self._search:isvisible()
end

---@param uuid                          string
---@return                              eve.ux.select.IItem|nil
function M:get_item(uuid)
  return self._item_map[uuid]
end

---@return eve.ux.select.IItem|nil
---@return integer
function M:get_item_selected()
  local item, lnum = self._search:get_item_selected() ---@type eve.ux.search.IItem|nil, integer
  local select_item = item ~= nil and self._item_map[item.uuid] or nil ---@type eve.ux.select.IItem|nil
  return select_item, lnum
end

---@return                              std.t.IScoredMatch[]
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

---@param text                          string
---@return nil
function M:reset_input(text)
  self._search:reset_input(text)
end

---@return nil
function M:resize()
  self._search:resize()
end

---@return nil
function M:toggle()
  self._search:toggle()
end

return M
