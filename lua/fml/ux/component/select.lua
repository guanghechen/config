local Observable = require("eve.lib.collection.observable")
local icons = require("eve.lib.icons")
local oxi = require("eve.lib.oxi")
local state = require("eve.state")
local Search = require("fml.ux.component.search.search")

---@class fml.ux.Select : fml.t.ux.ISelect
---@field protected _case_sensitive     eve.lib.collection.IObservable
---@field protected _cmp                fml.t.ux.select.IMatchedItemCmp|nil
---@field protected _flag_fuzzy         eve.lib.collection.IObservable
---@field protected _flag_regex         eve.lib.collection.IObservable
---@field protected _frecency           eve.lib.collection.IFrecency|nil
---@field protected _full_matches       fml.t.ux.select.IMatchedItem[]
---@field protected _item_map           table<string, fml.t.ux.select.IItem>
---@field protected _item_uuid_cursor   string|nil
---@field protected _item_uuid_present  string|nil
---@field protected _last_case_sensitive boolean
---@field protected _last_input         string|nil
---@field protected _live_data_dirty    eve.lib.collection.IObservable
---@field protected _matches            fml.t.ux.select.IMatchedItem[]
---@field protected _provider           fml.t.ux.select.IProvider
---@field protected _get_search         fun(): fml.t.ux.search.ISearch
local M = {}
M.__index = M

---@class fml.t.ux.select.IProps
---@field public case_sensitive         ?eve.lib.collection.IObservable
---@field public cmp                    ?fml.t.ux.select.IMatchedItemCmp
---@field public delay_fetch            ?integer
---@field public delay_render           ?integer
---@field public dimension              ?fml.t.ux.search.IRawDimension
---@field public dirty_on_invisible     ?boolean
---@field public preview_enabled        boolean
---@field public preview_flag_wrap      ?boolean
---@field public extend_preset_keymaps  ?boolean
---@field public flag_fuzzy             ?eve.lib.collection.IObservable
---@field public flag_regex             ?eve.lib.collection.IObservable
---@field public frecency               ?eve.lib.collection.IFrecency
---@field public input                  ?eve.lib.collection.IObservable
---@field public input_history          ?eve.lib.collection.IHistory
---@field public input_keymaps          ?eve.t.IKeymap[]
---@field public main_keymaps           ?eve.t.IKeymap[]
---@field public permanent              ?boolean
---@field public preview_keymaps        ?eve.t.IKeymap[]
---@field public provider               fml.t.ux.select.IProvider
---@field public statusline_items       ?eve.t.ux.widget.IRawStatuslineItem[]
---@field public title                  string
---@field public on_close               ?fml.t.ux.search.IOnClose
---@field public on_confirm             fml.t.ux.select.IOnConfirm
---@field public on_invisible           ?fml.t.ux.search.IOnInvisible
---@field public on_preview_rendered    ?fml.t.ux.search.IOnPreviewRendered

---@param props                         fml.t.ux.select.IProps
---@return fml.ux.Select
function M.new(props)
  local self = setmetatable({}, M)

  local case_sensitive = props.case_sensitive or Observable.from_value(false) ---@type eve.lib.collection.IObservable
  local cmp = props.cmp ---@type fml.t.ux.select.IMatchedItemCmp|nil
  local delay_fetch = props.delay_fetch or 128 ---@type integer
  local delay_render = props.delay_render or 48 ---@type integer
  local dimension = props.dimension ---@type fml.t.ux.search.IRawDimension|nil
  local dirty_on_invisible = not not props.dirty_on_invisible ---@type boolean
  local preview_enabled = props.preview_enabled ---@type boolean
  local preview_flag_wrap = props.preview_flag_wrap ---@type boolean|nil
  local extend_preset_keymaps = not not props.extend_preset_keymaps ---@type boolean
  local flag_fuzzy = props.flag_fuzzy or Observable.from_value(false) ---@type eve.lib.collection.IObservable
  local flag_regex = props.flag_regex or Observable.from_value(false) ---@type eve.lib.collection.IObservable
  local frecency = props.frecency ---@type eve.lib.collection.IFrecency|nil
  local input = props.input or Observable.from_value("") ---@type eve.lib.collection.IObservable
  local input_history = props.input_history ---@type eve.lib.collection.IHistory|nil
  local input_keymaps = props.input_keymaps ---@type eve.t.IKeymap[]|nil
  local live_data_dirty = Observable.from_value(true) ---@type eve.lib.collection.IObservable
  local main_keymaps = props.main_keymaps ---@type eve.t.IKeymap[]|nil
  local permanent = props.permanent ---@type boolean|nil
  local preview_keymaps = props.preview_keymaps ---@type eve.t.IKeymap[]|nil
  local provider = props.provider ---@type fml.t.ux.select.IProvider
  local statusline_items = props.statusline_items ---@type eve.t.ux.widget.IRawStatuslineItem[]
  local title = props.title ---@type string
  local on_confirm_from_props = props.on_confirm ---@type fml.t.ux.select.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.t.ux.search.IOnClose|nil
  local on_invisible_from_props = props.on_invisible ---@type fml.t.ux.search.IOnInvisible|nil
  local on_preview_rendered = props.on_preview_rendered ---@type fml.t.ux.search.IOnPreviewRendered|nil

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

    ---@type eve.t.ux.widget.IRawStatuslineItem[]
    statusline_items = vim.list_extend(statusline_items or {}, {
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
        key = "<leader>i",
        callback = toggle_case_sensitive,
        desc = "select: toggle case sensitive",
      },
      {
        modes = { "n", "v" },
        key = "<leader>r",
        callback = toggle_flag_regex,
        desc = "select: toggle flag regex",
      },
    }

    input_keymaps = vim.list_extend(vim.list_slice(preset_keymaps), input_keymaps or {})
    main_keymaps = vim.list_extend(vim.list_slice(preset_keymaps), main_keymaps or {})
    preview_keymaps = vim.list_extend(vim.list_slice(preset_keymaps), preview_keymaps or {})
  end ---@type fml.t.ux.search.IFetchPreviewData|nil

  local fetch_preview_data = nil
  if preview_enabled and provider.fetch_preview_data ~= nil then
    fetch_preview_data = function(item)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type fml.t.ux.select.IItem|nil
      return select_item ~= nil and provider.fetch_preview_data(select_item) or nil
    end
  end

  ---@type fml.t.ux.search.IPatchPreviewData|nil
  local patch_preview_data = nil
  if preview_enabled and provider.patch_preview_data ~= nil then
    patch_preview_data = function(item, last_item, data)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type fml.t.ux.select.IItem
      ---@diagnostic disable-next-line: invisible
      local last_select_item = self._item_map[last_item.uuid] ---@type fml.t.ux.select.IItem
      return provider.patch_preview_data(select_item, last_select_item, data)
    end
  end

  ---@param input_text                  string
  ---@param force                       boolean
  ---@param callback                    fml.t.ux.search.IFetchDataCallback
  ---@return nil
  local function fetch_data(input_text, force, callback)
    vim.schedule(function()
      local ok, data = pcall(self.fetch_data, self, input_text, force)
      callback(ok, data)
    end)
  end

  ---@param item                        fml.t.ux.search.IItem
  ---@return eve.e.WidgetConfirmAction|nil
  local function on_confirm(item)
    if frecency ~= nil then
      frecency:access(item.uuid)
    end
    ---@diagnostic disable-next-line: invisible
    local select_item = self._item_map[item.uuid] ---@type fml.t.ux.select.IItem
    if select_item ~= nil then
      return on_confirm_from_props(select_item)
    end
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

  local _search = nil ---@type fml.t.ux.search.ISearch|nil

  ---@return fml.t.ux.search.ISearch
  local function get_search()
    if _search == nil then
      _search = Search.new({
        delay_fetch = delay_fetch,
        delay_render = delay_render,
        dimension = dimension,
        enable_multiline_input = false,
        fetch_data = fetch_data,
        fetch_preview_data = fetch_preview_data,
        input = input,
        input_history = input_history,
        input_keymaps = input_keymaps,
        main_keymaps = main_keymaps,
        patch_preview_data = patch_preview_data,
        permanent = permanent,
        preview_flag_wrap = preview_flag_wrap,
        preview_keymaps = preview_keymaps,
        statusline_items = statusline_items,
        title = title,
        on_confirm = on_confirm,
        on_close = on_close_from_props,
        on_invisible = on_invisible,
        on_preview_rendered = on_preview_rendered,
      })
    end
    return _search
  end

  self._case_sensitive = case_sensitive
  self._cmp = cmp
  self._flag_fuzzy = flag_fuzzy
  self._flag_regex = flag_regex
  self._frecency = frecency
  self._full_matches = {}
  self._item_map = {}
  self._item_uuid_present = nil
  self._item_uuid_cursor = nil
  self._last_input = nil ---@type string|nil
  self._last_case_sensitive = case_sensitive:snapshot()
  self._live_data_dirty = live_data_dirty
  self._matches = {}
  self._provider = provider
  self._get_search = get_search

  return self
end

---@param dimension                     fml.t.ux.search.IRawDimension
---@return nil
function M:change_dimension(dimension)
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  search:change_dimension(dimension)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  search:change_input_title(title)
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  search:change_preview_title(title)
end

---@return nil
function M:close()
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  search:close()
end

---@param item1                         fml.t.ux.select.IMatchedItem
---@param item2                         fml.t.ux.select.IMatchedItem
---@return boolean
function M.cmp_by_score(item1, item2)
  if item1.score == item2.score then
    return item1.order < item2.order
  end
  return item1.score > item2.score
end

---@param item                          fml.t.ux.select.IItem
---@param match                         fml.t.ux.select.IMatchedItem
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
---@return fml.t.ux.search.IData
function M:fetch_data(input, force)
  local is_data_dirty = force or self._live_data_dirty:snapshot() ---@type boolean
  self._live_data_dirty:next(false)

  if is_data_dirty then
    local frecency = self._frecency ---@type eve.lib.collection.IFrecency|nil
    local data = self._provider.fetch_data(force) ---@type fml.t.ux.select.IData
    local item_map = {} ---@type table<string, fml.t.ux.select.IItem>
    local full_matches = {} ---@type fml.t.ux.select.IMatchedItem[]
    for order, item in ipairs(data.items) do
      local score = frecency ~= nil and frecency:score(item.uuid) or 0 ---@type integer
      local match_item = { order = order, uuid = item.uuid, score = score, matches = {} } ---@type fml.t.ux.select.IMatchedItem
      item_map[item.uuid] = item
      table.insert(full_matches, match_item)
    end

    if self._cmp then
      table.sort(full_matches, self._cmp)
    end

    self._item_uuid_present = data.present_uuid
    self._item_uuid_cursor = data.cursor_uuid
    self._item_map = item_map
    self._full_matches = full_matches
    self._matches = full_matches
  end

  local item_map = self._item_map ---@type table<string, fml.t.ux.select.IItem>
  local matches = self:filter(input) ---@type fml.t.ux.select.IMatchedItem[]
  local items = {} ---@type fml.t.ux.search.IItem[]
  local render_item = self._provider.render_item or M.default_render_item ---@type fml.t.ux.select.IRenderItem
  for _, match in ipairs(matches) do
    local item = item_map[match.uuid] ---@type fml.t.ux.select.IItem
    local line, highlights = render_item(item, match)
    ---@type fml.t.ux.search.IItem
    local search_item = { group = item.group, uuid = item.uuid, text = line, highlights = highlights }
    table.insert(items, search_item)
  end

  ---@type fml.t.ux.search.IData
  return { items = items, present_uuid = self._item_uuid_present, cursor_uuid = self._item_uuid_cursor }
end

---@param input                         string
---@return fml.t.ux.select.IMatchedItem[]
function M:filter(input)
  local frecency = self._frecency ---@type eve.lib.collection.IFrecency|nil
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean

  local matches = self._full_matches ---@type fml.t.ux.select.IMatchedItem[]
  if #input < 1 then
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = frecency:score(uuid)
      end
    end
  else
    local old_matches = self._full_matches ---@type fml.t.ux.select.IMatchedItem[]
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

    ---@type fml.t.ux.select.IMatchedItem[]
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
---@param old_matches                   fml.t.ux.select.IMatchedItem[]
---@return fml.t.ux.select.IMatchedItem[]
function M:find_matched_items(input, old_matches)
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean
  local flag_fuzzy = self._flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self._flag_regex:snapshot() ---@type boolean
  local item_map = self._item_map ---@type table<string, fml.t.ux.select.IItem>

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
      local item = item_map[uuid] ---@type fml.t.ux.select.IItem|nil
      if item ~= nil then
        item.text_lower = item.text_lower or item.text:lower()
        table.insert(lines, item.text_lower)
      end
    end
  end

  ---@type eve.lib.oxi.string.ILineMatch[]|nil
  local oxi_matches = oxi.find_match_points_line_by_line(input, lines, flag_fuzzy, flag_regex)
  if oxi_matches == nil then
    return old_matches
  end

  local matches = {} ---@type fml.t.ux.select.IMatchedItem[]
  for _, oxi_match in ipairs(oxi_matches) do
    local old_match = old_matches[oxi_match.lnum] ---@type fml.t.ux.select.IMatchedItem

    ---@type fml.t.ux.select.IMatchedItem
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
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  search:focus()
end

---@param uuid                          string
---@return                              fml.t.ux.select.IItem|nil
function M:get_item(uuid)
  return self._item_map[uuid]
end

---@return                              fml.t.ux.select.IMatchedItem[]
function M:get_matched_items()
  return self._matches
end

---@return integer|nil
function M:get_winnr_main()
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  return search:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  return search:get_winnr_input()
end

---@return integer|nil
function M:get_winnr_preview()
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  return search:get_winnr_preview()
end

---@return nil
function M:mark_data_dirty()
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  self._live_data_dirty:next(true)
  search.state.dirtier_data:mark_dirty()
end

---@return nil
function M:mark_search_state_dirty()
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  search.state.dirtier_data:mark_dirty()
end

---@return nil
function M:open()
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  search:open()
end

---@return nil
function M:toggle()
  local search = self._get_search() ---@type fml.t.ux.search.ISearch
  search:toggle()
end

return M
