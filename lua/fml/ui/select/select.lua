local Search = require("fml.ui.search.search")
local defaults = require("fml.ui.select.defaults")

---@class fm.types.ui.select.IItemData
---@field public idx                    integer

---@param items                         fml.types.ui.select.IItem[]
---@param frecency                      fml.types.collection.IFrecency|nil
---@param cmp                           fml.types.ui.select.ILineMatchCmp
---@return fml.types.ui.select.ILineMatch[]
local function process_full_matches(items, frecency, cmp)
  local full_matches = {} ---@type fml.types.ui.select.ILineMatch[]
  if frecency ~= nil then
    for idx, item in ipairs(items) do
      local match = { idx = idx, score = frecency:score(item.uuid), pieces = {} } ---@type fml.types.ui.select.ILineMatch
      table.insert(full_matches, match)
    end
  else
    for idx in ipairs(items) do
      local match = { idx = idx, score = 0, pieces = {} } ---@type fml.types.ui.select.ILineMatch
      table.insert(full_matches, match)
    end
  end
  table.sort(full_matches, cmp)
  return full_matches
end

---@param full_matches                  fml.types.ui.select.ILineMatch[]
---@param items                         fml.types.ui.select.IItem[]
---@param frecency                      fml.types.collection.IFrecency|nil
---@param cmp                           fml.types.ui.select.ILineMatchCmp
---@return nil
local function refresh_full_matches(full_matches, items, frecency, cmp)
  for _, match in ipairs(full_matches) do
    local idx = match.idx ---@type integer
    local item = items[idx] ---@type fml.types.ui.select.IItem|nil
    local uuid = item and item.uuid or ""
    match.score = frecency and frecency:score(uuid) or 0
  end
  table.sort(full_matches, cmp)
end

---@class fml.ui.select.Select : fml.types.ui.select.ISelect
---@field protected _cmp                fml.types.ui.select.ILineMatchCmp
---@field protected _frecency           fml.types.collection.IFrecency|nil
---@field protected _full_matches       fml.types.ui.select.ILineMatch[]
---@field protected _items              fml.types.ui.select.IItem[]
---@field protected _match              fml.types.ui.select.IMatch
---@field protected _matches            fml.types.ui.select.ILineMatch[]
---@field protected _render_line        fml.types.ui.select.main.IRenderLine
---@field protected _search             fml.types.ui.search.ISearch
---@field protected _last_input_lower   string|nil
local M = {}
M.__index = M

---@class fml.types.ui.select.IProps
---@field public title                  string
---@field public items                  fml.types.ui.select.IItem[]
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public frecency               fml.types.collection.IFrecency|nil
---@field public cmp                    ?fml.types.ui.select.ILineMatchCmp
---@field public match                  ?fml.types.ui.select.IMatch
---@field public render_line            ?fml.types.ui.select.main.IRenderLine
---@field public input_keymaps          ?fml.types.IKeymap[]
---@field public main_keymaps           ?fml.types.IKeymap[]
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
---@field public height                 ?number
---@field public on_confirm             fml.types.ui.select.IOnConfirm
---@field public on_close               ?fml.types.ui.select.IOnClose

---@param props                         fml.types.ui.select.IProps
---@return fml.ui.select.Select
function M.new(props)
  local self = setmetatable({}, M)

  local title = props.title ---@type string
  local items = props.items ---@type fml.types.ui.select.IItem[]
  local input = props.input ---@type fml.types.collection.IObservable
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local frecency = props.frecency ---@type fml.types.collection.IFrecency|nil
  local cmp = props.cmp or defaults.line_match_cmp ---@type fml.types.ui.select.ILineMatchCmp
  local match = props.match or defaults.match ---@type fml.types.ui.select.IMatch
  local render_line = props.render_line or defaults.render_line ---@type fml.types.ui.select.main.IRenderLine
  local input_keymaps = props.input_keymaps or {} ---@type fml.types.IKeymap[]
  local main_keymaps = props.main_keymaps or {} ---@type fml.types.IKeymap[]
  local max_width = props.max_width or 0.8 ---@type number
  local max_height = props.max_height or 0.8 ---@type number
  local width = props.width ---@type number|nil
  local height = props.height ---@type number|nil
  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.select.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.types.ui.search.IOnClose|nil
  local full_matches = process_full_matches(items, frecency, cmp)

  ---@param item                        fml.types.ui.search.IItem
  ---@return nil
  local function on_confirm(item)
    if frecency ~= nil then
      frecency:access(item.uuid)
    end
    local data = item.data ---@type fm.types.ui.select.IItemData
    local idx = data.idx ---@type integer
    ---@diagnostic disable-next-line: invisible
    local select_item = self._items[idx] ---@type fml.types.ui.select.IItem
    if idx ~= nil and select_item ~= nil then
      return on_confirm_from_props(select_item, idx)
    end
  end

  self._cmp = cmp
  self._frecency = frecency
  self._full_matches = full_matches
  self._items = items
  self._matches = full_matches
  self._match = match
  self._render_line = render_line
  self._last_input_lower = nil ---@type string|nil

  ---@param input_text                  string
  ---@param callback                    fml.types.ui.search.IFetchItemsCallback
  ---@return nil
  local function fetch_items(input_text, callback)
    vim.defer_fn(function()
      local ok, search_items = pcall(self.fetch_items, self, input_text)
      callback(ok, search_items)
    end, 10)
  end

  ---@type fml.types.ui.search.ISearch
  local search = Search.new({
    title = title,
    input = input,
    fetch_items = fetch_items,
    input_history = input_history,
    input_keymaps = input_keymaps,
    main_keymaps = main_keymaps,
    max_width = max_width,
    max_height = max_height,
    width = width,
    height = height,
    on_confirm = on_confirm,
    on_close = on_close_from_props,
  })

  self.state = search.state
  self._search = search

  return self
end

---@param input                         string
---@return fml.types.ui.select.ILineMatch[]
function M:filter(input)
  local input_lower = input:lower() ---@type string
  local items = self._items ---@type fml.types.ui.select.IItem[]
  local frecency = self._frecency ---@type fml.types.collection.IFrecency|nil
  local cmp = self._cmp ---@type fml.types.ui.select.ILineMatchCmp
  local last_input_lower = self._last_input_lower ---@type string|nil
  self._last_input_lower = input_lower

  if #input < 1 then
    local matches = self._full_matches ---@type fml.types.ui.select.ILineMatch[]
    refresh_full_matches(matches, items, frecency, cmp)
    return matches
  end

  ---@type fml.types.ui.select.ILineMatch[]
  local matches = (
    last_input_lower ~= nil
    and #input_lower > #last_input_lower
    and input_lower:sub(1, #last_input_lower) == last_input_lower
  )
      and self._match(input_lower, items, self._matches)
    or self._match(input_lower, items, self._full_matches)
  if frecency ~= nil then
    for _, match in ipairs(matches) do
      local item = items[match.idx] ---@type fml.types.ui.select.IItem
      match.score = match.score + frecency:score(item.uuid)
    end
  end
  table.sort(matches, self._cmp)
  return matches
end

---@param input                       string
---@return fml.types.ui.search.IItem[]
function M:fetch_items(input)
  local items = self._items ---@type fml.types.ui.select.IItem[]
  local matches = self:filter(input) ---@type fml.types.ui.select.ILineMatch[]
  local search_items = {} ---@type fml.types.ui.search.IItem[]
  for _, match in ipairs(matches) do
    local item = items[match.idx] ---@type fml.types.ui.select.IItem
    local line, highlights = self._render_line({ item = item, match = match }) ---@type string, fml.types.ui.printer.ILineHighlight[]
    local data = { idx = match.idx } ---@type fm.types.ui.select.IItemData
    ---@type fml.types.ui.search.IItem
    local search_item = {
      uuid = item.uuid,
      text = line,
      highlights = highlights,
      data = data,
    }
    table.insert(search_items, search_item)
  end
  return search_items
end

---@param items                         fml.types.ui.select.IItem[]
---@return nil
function M:update_items(items)
  local frecency = self._frecency ---@type fml.types.collection.IFrecency
  local cmp = self._cmp ---@type fml.types.ui.select.ILineMatchCmp
  local full_matches = process_full_matches(items, frecency, cmp)
  self._items = items
  self._full_matches = full_matches
  self._matches = full_matches
  self._search.state:mark_items_dirty()
end

---@return integer|nil
function M:get_winnr_main()
  return self._search:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  return self._search:get_winnr_input()
end

---@return nil
function M:close()
  self._search:close()
end

---@return nil
function M:open()
  self._search:open()
end

---@return nil
function M:toggle()
  self._search:toggle()
end

return M
