local Observable = require("fml.collection.observable")
local std_array = require("fml.std.array")
local oxi = require("fml.std.oxi")
local icons = require("fml.ui.icons")
local Search = require("fml.ui.search.search")

---@param item                          fml.types.ui.select.IItem
---@param match                         fml.types.ui.select.ILineMatch
---@return string
---@return fml.types.ui.IInlineHighlight[]
local function default_render_item(item, match)
  local highlights = {} ---@type fml.types.ui.IInlineHighlight[]
  for _, piece in ipairs(match.pieces) do
    ---@type fml.types.ui.IInlineHighlight[]
    local highlight = { coll = piece.l, colr = piece.r, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return item.text, highlights
end

---@param params                        fml.types.ui.select.IMatchParams
---@return fml.types.ui.select.ILineMatch[]
local function default_match(params)
  local input = params.input ---@type string
  local case_sensitive = params.case_sensitive ---@type boolean
  local item_map = params.item_map ---@type table<string, fml.types.ui.select.IItem>
  local old_matches = params.old_matches ---@type fml.types.ui.select.ILineMatch[]

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
      local item = item_map[uuid] ---@type fml.types.ui.select.IItem|nil
      if item ~= nil then
        item.text_lower = item.text_lower or item.text:lower()
        table.insert(lines, item.text_lower)
      end
    end
  end

  local oxi_matches = oxi.find_match_points(input, lines) ---@type fml.std.oxi.string.ILineMatch[]
  local matches = {} ---@type fml.types.ui.select.ILineMatch[]
  for _, oxi_match in ipairs(oxi_matches) do
    ---! The index in lua is start from 1 but rust is start from 0.
    local old_match = old_matches[oxi_match.idx + 1] ---@type fml.types.ui.select.ILineMatch

    ---@type fml.types.ui.select.ILineMatch
    local match = {
      order = old_match.order,
      uuid = old_match.uuid,
      score = oxi_match.score,
      pieces = oxi_match.pieces,
    }
    table.insert(matches, match)
  end
  return matches
end

---@param item1                         fml.types.ui.select.ILineMatch
---@param item2                         fml.types.ui.select.ILineMatch
---@return boolean
local function default_match_cmp(item1, item2)
  if item1.score == item2.score then
    return item1.order < item2.order
  end
  return item1.score > item2.score
end

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

---@class fml.ui.Select : fml.types.ui.ISelect
---@field protected _case_sensitive     fml.types.collection.IObservable
---@field protected _cmp                fml.types.ui.select.ILineMatchCmp
---@field protected _frecency           fml.types.collection.IFrecency|nil
---@field protected _full_matches       fml.types.ui.select.ILineMatch[]
---@field protected _item_map           table<string, fml.types.ui.select.IItem>
---@field protected _match              fml.types.ui.select.IMatch
---@field protected _matches            fml.types.ui.select.ILineMatch[]
---@field protected _render_item        fml.types.ui.select.IRenderItem
---@field protected _search             fml.types.ui.search.ISearch
---@field protected _last_case_sensitive boolean
---@field protected _last_input         string|nil
local M = {}
M.__index = M

---@class fml.types.ui.select.IProps
---@field public title                  string
---@field public destroy_on_close       boolean
---@field public items                  fml.types.ui.select.IItem[]
---@field public statusline_items       ?fml.types.ui.search.IRawStatuslineItem[]
---@field public case_sensitive         ?fml.types.collection.IObservable
---@field public input                  ?fml.types.collection.IObservable
---@field public input_history          ?fml.types.collection.IHistory|nil
---@field public frecency               ?fml.types.collection.IFrecency|nil
---@field public cmp                    ?fml.types.ui.select.ILineMatchCmp
---@field public match                  ?fml.types.ui.select.IMatch
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
---@field public on_confirm             fml.types.ui.select.IOnConfirm
---@field public on_close               ?fml.types.ui.search.IOnClose
---@field public on_preview_rendered    ?fml.types.ui.search.preview.IOnRendered
---@field public on_resume              ?fml.types.ui.search.IOnResume
---@field public render_item            ?fml.types.ui.select.IRenderItem

---@param props                         fml.types.ui.select.IProps
---@return fml.ui.Select
function M.new(props)
  local self = setmetatable({}, M)

  local title = props.title ---@type string
  local destroy_on_close = props.destroy_on_close ---@type boolean
  local items = props.items ---@type fml.types.ui.select.IItem[]
  local statusline_items = props.statusline_items ---@type fml.types.ui.search.IRawStatuslineItem[]
  local case_sensitive = props.case_sensitive or Observable.from_value(false) ---@type fml.types.collection.IObservable
  local input = props.input or Observable.from_value("") ---@type fml.types.collection.IObservable
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local frecency = props.frecency ---@type fml.types.collection.IFrecency|nil
  local cmp = props.cmp or default_match_cmp ---@type fml.types.ui.select.ILineMatchCmp
  local match = props.match or default_match ---@type fml.types.ui.select.IMatch
  local input_keymaps = props.input_keymaps ---@type fml.types.IKeymap[]|nil
  local main_keymaps = props.main_keymaps ---@type fml.types.IKeymap[]|nil
  local preview_keymaps = props.preview_keymaps ---@type fml.types.IKeymap[]|nil
  local fetch_preview_data_from_props = props.fetch_preview_data ---@type fml.types.ui.select.preview.IFetchData|nil
  local patch_preview_data_from_props = props.patch_preview_data ---@type fml.types.ui.select.preview.IPatchData|nil
  local max_width = props.max_width or 0.8 ---@type number
  local max_height = props.max_height or 0.8 ---@type number
  local width = props.width ---@type number|nil
  local height = props.height ---@type number|nil
  local width_preview = props.width_preview ---@type number|nil
  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.select.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.types.ui.search.IOnClose|nil
  local on_preview_rendered = props.on_preview_rendered ---@type fml.types.ui.search.preview.IOnRendered|nil
  local on_resume = props.on_resume ---@type fml.types.ui.search.IOnResume|nil
  local render_item = props.render_item or default_render_item ---@type fml.types.ui.select.IRenderItem

  local item_map, full_matches = process_items(cmp, frecency, items)

  if statusline_items == nil then
    ---@return nil
    local function toggle_case_sensitive()
      local flag = case_sensitive:snapshot() ---@type boolean
      case_sensitive:next(not flag)
      vim.cmd("redrawstatus")
      self:refresh()
    end

    ---@type fml.types.ui.search.IRawStatuslineItem[]
    statusline_items = {
      {
        type = "flag",
        desc = "select: toggle case sensitive",
        symbol = icons.symbols.flag_case_sensitive,
        state = case_sensitive,
        callback = toggle_case_sensitive,
      },
    }

    ---@type fml.types.IKeymap[]
    local default_keymaps = {
      {
        modes = { "n", "v" },
        key = "<leader>i",
        callback = toggle_case_sensitive,
        desc = "select: toggle case sensitive",
      },
    }

    input_keymaps = std_array.concat(input_keymaps or {}, default_keymaps)
    main_keymaps = std_array.concat(main_keymaps or {}, default_keymaps)
    preview_keymaps = std_array.concat(preview_keymaps or {}, default_keymaps)
  end ---@type fml.types.ui.search.preview.IFetchData|nil

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
    statusline_items = statusline_items,
    input_keymaps = input_keymaps,
    main_keymaps = main_keymaps,
    preview_keymaps = preview_keymaps,
    fetch_delay = 32,
    render_delay = 32,
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
    on_resume = on_resume,
  })

  self.state = search.state
  self._case_sensitive = case_sensitive
  self._cmp = cmp
  self._frecency = frecency
  self._full_matches = full_matches
  self._item_map = item_map
  self._match = match
  self._matches = full_matches
  self._render_item = render_item
  self._search = search
  self._last_case_sensitive = case_sensitive:snapshot() ---@type boolean
  self._last_input = nil ---@type string|nil
  return self
end

---@param input                         string
---@return fml.types.ui.select.ILineMatch[]
function M:filter(input)
  local frecency = self._frecency ---@type fml.types.collection.IFrecency|nil
  local case_sensitive = self._case_sensitive:snapshot() ---@type boolean

  local matches = self._full_matches ---@type fml.types.ui.select.ILineMatch[]
  if #input < 1 then
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = frecency:score(uuid)
      end
    end
  else
    local old_matches = self._full_matches ---@type fml.types.ui.select.ILineMatch[]
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

    ---@type fml.types.ui.select.ILineMatch[]
    matches = self._match({
      input = input,
      case_sensitive = case_sensitive,
      item_map = self._item_map,
      old_matches = old_matches,
    })
    if frecency ~= nil then
      for _, match in ipairs(matches) do
        local uuid = match.uuid ---@type string
        match.score = match.score + frecency:score(uuid)
      end
    end
  end

  table.sort(matches, self._cmp)
  self._last_case_sensitive = case_sensitive
  self._last_input = input
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
    local line, highlights = self._render_item(item, match)
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

---@return integer|nil
function M:get_winnr_main()
  return self._search:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  return self._search:get_winnr_input()
end

---@return integer|nil
function M:get_winnr_preview()
  return self._search:get_winnr_preview()
end

---@return nil
function M:refresh()
  self._search.state:mark_dirty()
end

---@param items                         fml.types.ui.select.IItem[]
---@return nil
function M:update_data(items)
  local cmp = self._cmp ---@type fml.types.ui.select.ILineMatchCmp
  local frecency = self._frecency ---@type fml.types.collection.IFrecency
  local item_map, full_matches = process_items(cmp, frecency, items)
  self._item_map = item_map
  self._full_matches = full_matches
  self._matches = full_matches
  self:refresh()
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
function M:resume()
  self._search:resume()
end

---@return nil
function M:toggle()
  self._search:toggle()
end

return M
