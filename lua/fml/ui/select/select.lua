local Search = require("fml.ui.search.search")
local defaults = require("fml.ui.select.defaults")

---@param cmp                           fml.types.ui.select.ILineMatchCmp
---@param frecency                      fml.types.collection.IFrecency|nil
---@param items                         fml.types.ui.select.IItem[]
---@return table<string, fml.types.ui.select.IItem>
---@return fml.types.ui.select.ILineMatch[]
local function process_items(cmp, frecency, items)
  local item_map = {} ---@type table<string, fml.types.ui.select.IItem>
  local full_matches = {} ---@type fml.types.ui.select.ILineMatch[]
  for order, item in ipairs(items) do
    local score = frecency ~= nil and frecency:score(item.uuid) or 0 ---@type integer
    local match = { order = order, uuid = item.uuid, score = score, pieces = {} } ---@type fml.types.ui.select.ILineMatch
    item_map[item.uuid] = item
    table.insert(full_matches, match)
  end
  table.sort(full_matches, cmp)
  return item_map, full_matches
end

---@class fml.ui.select.Select : fml.types.ui.select.ISelect
---@field protected _cmp                fml.types.ui.select.ILineMatchCmp
---@field protected _frecency           fml.types.collection.IFrecency|nil
---@field protected _full_matches       fml.types.ui.select.ILineMatch[]
---@field protected _item_map           table<string, fml.types.ui.select.IItem>
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
---@field public preview_keymaps        ?fml.types.IKeymap[]
---@field public fetch_preview_data     ?fml.types.ui.select.preview.IFetchData
---@field public patch_preview_data     ?fml.types.ui.select.preview.IPatchData
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
---@field public height                 ?number
---@field public width_preview          ?number
---@field public destroy_on_close       ?boolean
---@field public on_confirm             fml.types.ui.select.IOnConfirm
---@field public on_close               ?fml.types.ui.select.IOnClose
---@field public on_preview_rendered    ?fml.types.ui.search.preview.IOnRendered

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
  local preview_keymaps = props.preview_keymaps or {} ---@type fml.types.IKeymap[]
  local fetch_preview_data_from_props = props.fetch_preview_data ---@type fml.types.ui.select.preview.IFetchData|nil
  local patch_preview_data_from_props = props.patch_preview_data ---@type fml.types.ui.select.preview.IPatchData|nil
  local max_width = props.max_width or 0.8 ---@type number
  local max_height = props.max_height or 0.8 ---@type number
  local width = props.width ---@type number|nil
  local height = props.height ---@type number|nil
  local width_preview = props.width_preview ---@type number|nil
  local destroy_on_close = props.destroy_on_close ---@type boolean|nil
  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.select.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.types.ui.search.IOnClose|nil
  local on_preview_rendered = props.on_preview_rendered ---@type fml.types.ui.search.preview.IOnRendered|nil

  local item_map, full_matches = process_items(cmp, frecency, items)

  ---@type fml.types.ui.search.preview.IFetchData|nil
  local fetch_preview_data = nil
  if fetch_preview_data_from_props ~= nil then
    fetch_preview_data = function(item)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type fml.types.ui.select.IItem|nil
      return select_item ~= nil and fetch_preview_data_from_props(select_item) or nil
    end
  end

  ---@type fml.types.ui.search.preview.IPatchData|nil
  local patch_preview_data = nil
  if patch_preview_data_from_props ~= nil then
    patch_preview_data = function(item, last_item, data)
      ---@diagnostic disable-next-line: invisible
      local select_item = self._item_map[item.uuid] ---@type fml.types.ui.select.IItem
      ---@diagnostic disable-next-line: invisible
      local last_select_item = self._item_map[last_item.uuid] ---@type fml.types.ui.select.IItem
      return patch_preview_data_from_props(select_item, last_select_item, data)
    end
  end

  ---@param input_text                  string
  ---@param callback                    fml.types.ui.search.IFetchItemsCallback
  ---@return nil
  local function fetch_items(input_text, callback)
    vim.schedule(function()
      local ok, search_items = pcall(self.fetch_items, self, input_text)
      callback(ok, search_items)
    end)
  end

  ---@param item                        fml.types.ui.search.IItem
  ---@return nil
  local function on_confirm(item)
    if frecency ~= nil then
      frecency:access(item.uuid)
    end
    ---@diagnostic disable-next-line: invisible
    local select_item = self._item_map[item.uuid] ---@type fml.types.ui.select.IItem
    if select_item ~= nil then
      return on_confirm_from_props(select_item)
    end
  end

  ---@type fml.types.ui.search.ISearch
  local search = Search.new({
    title = title,
    input = input,
    fetch_items = fetch_items,
    input_history = input_history,
    input_keymaps = input_keymaps,
    main_keymaps = main_keymaps,
    preview_keymaps = preview_keymaps,
    fetch_preview_data = fetch_preview_data,
    patch_preview_data = patch_preview_data,
    max_width = max_width,
    max_height = max_height,
    width = width,
    height = height,
    width_preview = width_preview,
    destroy_on_close = destroy_on_close,
    on_confirm = on_confirm,
    on_close = on_close_from_props,
    on_preview_rendered = on_preview_rendered,
  })

  self.state = search.state
  self._cmp = cmp
  self._frecency = frecency
  self._full_matches = full_matches
  self._item_map = item_map
  self._match = match
  self._matches = full_matches
  self._render_line = render_line
  self._search = search
  self._last_input_lower = nil ---@type string|nil
  return self
end

---@param input                         string
---@return fml.types.ui.select.ILineMatch[]
function M:filter(input)
  local input_lower = input:lower() ---@type string
  local frecency = self._frecency ---@type fml.types.collection.IFrecency|nil
  local last_input_lower = self._last_input_lower ---@type string|nil

  local matches = self._full_matches ---@type fml.types.ui.select.ILineMatch[]
  if #input < 1 then
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = frecency:score(uuid)
      end
    end
  else
    ---@type fml.types.ui.select.ILineMatch[]
    local old_matches = (
      last_input_lower ~= nil
      and #input_lower > #last_input_lower
      and input_lower:sub(1, #last_input_lower) == last_input_lower
    )
        and self._matches
      or self._full_matches

    ---@type fml.types.ui.select.ILineMatch[]
    matches = self._match(input_lower, self._item_map, old_matches)
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = match.score + frecency:score(uuid)
      end
    end
  end

  table.sort(matches, self._cmp)
  self._last_input_lower = input_lower
  self._matches = matches
  return matches
end

---@param input                       string
---@return fml.types.ui.search.IItem[]
function M:fetch_items(input)
  local item_map = self._item_map ---@type table<string, fml.types.ui.select.IItem>
  local matches = self:filter(input) ---@type fml.types.ui.select.ILineMatch[]
  local search_items = {} ---@type fml.types.ui.search.IItem[]
  for _, match in ipairs(matches) do
    local item = item_map[match.uuid] ---@type fml.types.ui.select.IItem
    local line, highlights = self._render_line({ item = item, match = match })
    ---@type fml.types.ui.search.IItem
    local search_item = {
      group = item.group,
      uuid = item.uuid,
      text = line,
      highlights = highlights,
    }
    table.insert(search_items, search_item)
  end
  return search_items
end

---@param items                         fml.types.ui.select.IItem[]
---@return nil
function M:update_items(items)
  local cmp = self._cmp ---@type fml.types.ui.select.ILineMatchCmp
  local frecency = self._frecency ---@type fml.types.collection.IFrecency
  local item_map, full_matches = process_items(cmp, frecency, items)
  self._item_map = item_map
  self._full_matches = full_matches
  self._matches = full_matches
  self._search.state:mark_dirty()
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
function M:focus()
  self._search:focus()
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
