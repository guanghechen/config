local Observable = require("eve.collection.observable")
local oxi = require("eve.oxi")
local std_array = require("eve.std.array")
local icons = require("eve.globals.icons")
local Search = require("fml.ux.component.search.search")

---@class fml.ux.Select : t.fml.ux.ISelect
---@field protected _case_sensitive     t.eve.collection.IObservable
---@field protected _cmp                t.fml.ux.select.IMatchedItemCmp|nil
---@field protected _flag_fuzzy         t.eve.collection.IObservable
---@field protected _flag_regex         t.eve.collection.IObservable
---@field protected _frecency           t.eve.collection.IFrecency|nil
---@field protected _full_matches       t.fml.ux.select.IMatchedItem[]
---@field protected _item_map           table<string, t.fml.ux.select.IItem>
---@field protected _item_uuid_cursor   string|nil
---@field protected _item_uuid_present  string|nil
---@field protected _last_case_sensitive boolean
---@field protected _last_input         string|nil
---@field protected _live_data_dirty    t.eve.collection.IObservable
---@field protected _matches            t.fml.ux.select.IMatchedItem[]
---@field protected _provider           t.fml.ux.select.IProvider
---@field protected _get_search         fun(): t.fml.ux.search.ISearch
local M = {}
M.__index = M

---@class t.fml.ux.select.IProps
---@field public case_sensitive         ?t.eve.collection.IObservable
---@field public cmp                    ?t.fml.ux.select.IMatchedItemCmp
---@field public delay_fetch            ?integer
---@field public delay_render           ?integer
---@field public dimension              ?t.fml.ux.search.IRawDimension
---@field public dirty_on_invisible     ?boolean
---@field public enable_preview         boolean
---@field public extend_preset_keymaps  ?boolean
---@field public flag_fuzzy             ?t.eve.collection.IObservable
---@field public flag_regex             ?t.eve.collection.IObservable
---@field public frecency               ?t.eve.collection.IFrecency
---@field public input                  ?t.eve.collection.IObservable
---@field public input_history          ?t.eve.collection.IHistory
---@field public input_keymaps          ?t.eve.IKeymap[]
---@field public main_keymaps           ?t.eve.IKeymap[]
---@field public permanent              ?boolean
---@field public preview_keymaps        ?t.eve.IKeymap[]
---@field public provider               t.fml.ux.select.IProvider
---@field public statusline_items       ?t.eve.ux.widget.IRawStatuslineItem[]
---@field public title                  string
---@field public on_close               ?t.fml.ux.search.IOnClose
---@field public on_confirm             t.fml.ux.select.IOnConfirm
---@field public on_invisible           ?t.fml.ux.search.IOnInvisible
---@field public on_preview_rendered    ?t.fml.ux.search.IOnPreviewRendered

---@param props                         t.fml.ux.select.IProps
---@return fml.ux.Select
function M.new(props)
  local self = setmetatable({}, M)

  local case_sensitive = props.case_sensitive or Observable.from_value(false) ---@type t.eve.collection.IObservable
  local cmp = props.cmp ---@type t.fml.ux.select.IMatchedItemCmp|nil
  local delay_fetch = props.delay_fetch or 128 ---@type integer
  local delay_render = props.delay_render or 48 ---@type integer
  local dimension = props.dimension ---@type t.fml.ux.search.IRawDimension|nil
  local dirty_on_invisible = not not props.dirty_on_invisible ---@type boolean
  local enable_preview = props.enable_preview ---@type boolean
  local extend_preset_keymaps = not not props.extend_preset_keymaps ---@type boolean
  local flag_fuzzy = props.flag_fuzzy or Observable.from_value(false) ---@type t.eve.collection.IObservable
  local flag_regex = props.flag_regex or Observable.from_value(false) ---@type t.eve.collection.IObservable
  local frecency = props.frecency ---@type t.eve.collection.IFrecency|nil
  local input = props.input or Observable.from_value("") ---@type t.eve.collection.IObservable
  local input_history = props.input_history ---@type t.eve.collection.IHistory|nil
  local input_keymaps = props.input_keymaps ---@type t.eve.IKeymap[]|nil
  local live_data_dirty = Observable.from_value(true) ---@type t.eve.collection.IObservable
  local main_keymaps = props.main_keymaps ---@type t.eve.IKeymap[]|nil
  local permanent = props.permanent ---@type boolean|nil
  local preview_keymaps = props.preview_keymaps ---@type t.eve.IKeymap[]|nil
  local provider = props.provider ---@type t.fml.ux.select.IProvider
  local statusline_items = props.statusline_items ---@type t.eve.ux.widget.IRawStatuslineItem[]
  local title = props.title ---@type string
  local on_confirm_from_props = props.on_confirm ---@type t.fml.ux.select.IOnConfirm
  local on_close_from_props = props.on_close ---@type t.fml.ux.search.IOnClose|nil
  local on_invisible_from_props = props.on_invisible ---@type t.fml.ux.search.IOnInvisible|nil
  local on_preview_rendered = props.on_preview_rendered ---@type t.fml.ux.search.IOnPreviewRendered|nil

  if statusline_items == nil or extend_preset_keymaps then
    ---@return nil
    local function toggle_case_sensitive()
      local flag = case_sensitive:snapshot() ---@type boolean
      case_sensitive:next(not flag)
      vim.cmd.redrawstatus()
      self:mark_search_state_dirty()
    end

    ---@return nil
    local function toggle_flag_fuzzy()
      local flag = flag_fuzzy:snapshot() ---@type boolean
      flag_fuzzy:next(not flag)
      vim.cmd.redrawstatus()
      self:mark_search_state_dirty()
    end

    ---@return nil
    local function toggle_flag_regex()
      local flag = flag_regex:snapshot() ---@type boolean
      flag_regex:next(not flag)
      vim.cmd.redrawstatus()
      self:mark_search_state_dirty()
    end

    ---@type t.eve.ux.widget.IRawStatuslineItem[]
    statusline_items = std_array.concat(statusline_items or {}, {
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

    ---@type t.eve.IKeymap[]
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

    input_keymaps = std_array.concat(input_keymaps or {}, preset_keymaps)
    main_keymaps = std_array.concat(main_keymaps or {}, preset_keymaps)
    preview_keymaps = std_array.concat(preview_keymaps or {}, preset_keymaps)
  end ---@type t.fml.ux.search.IFetchPreviewData|nil

  local fetch_preview_data = nil
  if enable_preview and provider.fetch_preview_data ~= nil then
    fetch_preview_data = function(item)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type t.fml.ux.select.IItem|nil
      return select_item ~= nil and provider.fetch_preview_data(select_item) or nil
    end
  end

  ---@type t.fml.ux.search.IPatchPreviewData|nil
  local patch_preview_data = nil
  if enable_preview and provider.patch_preview_data ~= nil then
    patch_preview_data = function(item, last_item, data)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type t.fml.ux.select.IItem
      ---@diagnostic disable-next-line: invisible
      local last_select_item = self._item_map[last_item.uuid] ---@type t.fml.ux.select.IItem
      return provider.patch_preview_data(select_item, last_select_item, data)
    end
  end

  ---@param input_text                  string
  ---@param force                       boolean
  ---@param callback                    t.fml.ux.search.IFetchDataCallback
  ---@return nil
  local function fetch_data(input_text, force, callback)
    vim.schedule(function()
      local ok, data = pcall(self.fetch_data, self, input_text, force)
      callback(ok, data)
    end)
  end

  ---@param item                        t.fml.ux.search.IItem
  ---@return t.eve.e.WidgetConfirmAction|nil
  local function on_confirm(item)
    if frecency ~= nil then
      frecency:access(item.uuid)
    end
    ---@diagnostic disable-next-line: invisible
    local select_item = self._item_map[item.uuid] ---@type t.fml.ux.select.IItem
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

  local _search = nil ---@type t.fml.ux.search.ISearch|nil

  ---@return t.fml.ux.search.ISearch
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

---@param dimension                     t.fml.ux.search.IRawDimension
---@return nil
function M:change_dimension(dimension)
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  search:change_dimension(dimension)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  search:change_input_title(title)
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  search:change_preview_title(title)
end

---@return nil
function M:close()
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  search:close()
end

---@param item1                         t.fml.ux.select.IMatchedItem
---@param item2                         t.fml.ux.select.IMatchedItem
---@return boolean
function M.cmp_by_score(item1, item2)
  if item1.score == item2.score then
    return item1.order < item2.order
  end
  return item1.score > item2.score
end

---@param item                          t.fml.ux.select.IItem
---@param match                         t.fml.ux.select.IMatchedItem
---@return string
---@return t.eve.IHighlightInline[]
function M.default_render_item(item, match)
  local highlights = {} ---@type t.eve.IHighlightInline[]
  for _, piece in ipairs(match.matches) do
    ---@type t.eve.IHighlightInline[]
    local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return item.text, highlights
end

---@param input                         string
---@param force                         boolean
---@return t.fml.ux.search.IData
function M:fetch_data(input, force)
  local is_data_dirty = force or self._live_data_dirty:snapshot() ---@type boolean
  self._live_data_dirty:next(false)

  if is_data_dirty then
    local frecency = self._frecency ---@type t.eve.collection.IFrecency|nil
    local data = self._provider.fetch_data(force) ---@type t.fml.ux.select.IData
    local item_map = {} ---@type table<string, t.fml.ux.select.IItem>
    local full_matches = {} ---@type t.fml.ux.select.IMatchedItem[]
    for order, item in ipairs(data.items) do
      local score = frecency ~= nil and frecency:score(item.uuid) or 0 ---@type integer
      local match_item = { order = order, uuid = item.uuid, score = score, matches = {} } ---@type t.fml.ux.select.IMatchedItem
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

  local item_map = self._item_map ---@type table<string, t.fml.ux.select.IItem>
  local matches = self:filter(input) ---@type t.fml.ux.select.IMatchedItem[]
  local items = {} ---@type t.fml.ux.search.IItem[]
  local render_item = self._provider.render_item or M.default_render_item ---@type t.fml.ux.select.IRenderItem
  for _, match in ipairs(matches) do
    local item = item_map[match.uuid] ---@type t.fml.ux.select.IItem
    local line, highlights = render_item(item, match)
    ---@type t.fml.ux.search.IItem
    local search_item = { group = item.group, uuid = item.uuid, text = line, highlights = highlights }
    table.insert(items, search_item)
  end

  ---@type t.fml.ux.search.IData
  return { items = items, present_uuid = self._item_uuid_present, cursor_uuid = self._item_uuid_cursor }
end

---@param input                         string
---@return t.fml.ux.select.IMatchedItem[]
function M:filter(input)
  local frecency = self._frecency ---@type t.eve.collection.IFrecency|nil
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean

  local matches = self._full_matches ---@type t.fml.ux.select.IMatchedItem[]
  if #input < 1 then
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = frecency:score(uuid)
      end
    end
  else
    local old_matches = self._full_matches ---@type t.fml.ux.select.IMatchedItem[]
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

    ---@type t.fml.ux.select.IMatchedItem[]
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
---@param old_matches                   t.fml.ux.select.IMatchedItem[]
---@return t.fml.ux.select.IMatchedItem[]
function M:find_matched_items(input, old_matches)
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean
  local flag_fuzzy = self._flag_fuzzy:snapshot() ---@type boolean
  local flag_regex = self._flag_regex:snapshot() ---@type boolean
  local item_map = self._item_map ---@type table<string, t.fml.ux.select.IItem>

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
      local item = item_map[uuid] ---@type t.fml.ux.select.IItem|nil
      if item ~= nil then
        item.text_lower = item.text_lower or item.text:lower()
        table.insert(lines, item.text_lower)
      end
    end
  end

  ---@type eve.oxi.string.ILineMatch[]|nil
  local oxi_matches = oxi.find_match_points_line_by_line(input, lines, flag_fuzzy, flag_regex)
  if oxi_matches == nil then
    return old_matches
  end

  local matches = {} ---@type t.fml.ux.select.IMatchedItem[]
  for _, oxi_match in ipairs(oxi_matches) do
    local old_match = old_matches[oxi_match.lnum] ---@type t.fml.ux.select.IMatchedItem

    ---@type t.fml.ux.select.IMatchedItem
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
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  search:focus()
end

---@param uuid                          string
---@return                              t.fml.ux.select.IItem|nil
function M:get_item(uuid)
  return self._item_map[uuid]
end

---@return                              t.fml.ux.select.IMatchedItem[]
function M:get_matched_items()
  return self._matches
end

---@return integer|nil
function M:get_winnr_main()
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  return search:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  return search:get_winnr_input()
end

---@return integer|nil
function M:get_winnr_preview()
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  return search:get_winnr_preview()
end

---@return nil
function M:mark_data_dirty()
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  self._live_data_dirty:next(true)
  search.state.dirtier_data:mark_dirty()
end

---@return nil
function M:mark_search_state_dirty()
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  search.state.dirtier_data:mark_dirty()
end

---@return nil
function M:open()
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  search:open()
end

---@return nil
function M:toggle()
  local search = self._get_search() ---@type t.fml.ux.search.ISearch
  search:toggle()
end

return M
