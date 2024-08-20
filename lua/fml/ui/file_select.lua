local fs = require("fml.std.fs")
local is = require("fml.std.is")
local path = require("fml.std.path")
local util = require("fml.std.util")
local api_state = require("fml.api.state")
local api_buf = require("fml.api.buf")
local Select = require("fml.ui.select")

---@param raw_items                         fml.types.ui.file_select.IRawItem[]
---@return fml.types.ui.select.IItem[]
---@return table<string, fml.types.ui.file_select.IItem>
local function cook_items(raw_items)
  local select_items = {} ---@type fml.types.ui.select.IItem[]
  local item_map = {} ---@type table<string, fml.types.ui.file_select.IItem>
  for _, raw_item in ipairs(raw_items) do
    ---@type fml.types.ui.select.IItem
    local select_item = { group = raw_item.group, uuid = raw_item.uuid, text = raw_item.filepath }
    table.insert(select_items, select_item)

    local filename = path.basename(raw_item.filepath)
    local icon, icon_hl = util.calc_fileicon(filename)

    ---@type fml.types.ui.file_select.IItem
    local item = {
      group = raw_item.group,
      uuid = raw_item.uuid,
      filepath = raw_item.filepath,
      filename = filename,
      icon = icon .. " ",
      icon_hl = icon_hl,
      lnum = raw_item.lnum,
      col = raw_item.col,
    }

    item_map[item.uuid] = item
  end
  return select_items, item_map
end

---@class fml.ui.FileSelect : fml.types.ui.IFileSelect
---@field protected cwd                 string
---@field protected item_map            table<string, fml.types.ui.file_select.IItem>
---@field protected _select             fml.types.ui.ISelect
local M = {}
M.__index = M

---@class fml.ui.file_select.IProps
---@field public cwd                    string
---@field public title                  string
---@field public items                  fml.types.ui.file_select.IRawItem[]
---@field public statusline_items       ?fml.types.ui.search.IRawStatuslineItem[]
---@field public case_sensitive         ?fml.types.collection.IObservable
---@field public input                  ?fml.types.collection.IObservable
---@field public input_history          ?fml.types.collection.IHistory
---@field public frecency               ?fml.types.collection.IFrecency
---@field public input_keymaps          ?fml.types.IKeymap[]
---@field public main_keymaps           ?fml.types.IKeymap[]
---@field public preview_keymaps        ?fml.types.IKeymap[]
---@field public preview                ?boolean

---@param props fml.ui.file_select.IProps
---@return fml.ui.FileSelect
function M.new(props)
  local self = setmetatable({}, M)

  ---@type fml.types.ui.select.IItem[], table<string, fml.types.ui.file_select.IItem>
  local select_items, item_map = cook_items(props.items)

  local cwd = props.cwd ---@type string
  local statusline_items = props.statusline_items ---@type fml.types.ui.search.IRawStatuslineItem[]|nil
  local case_sensitive = props.case_sensitive ---@type fml.types.collection.IObservable|nil
  local input = props.input ---@type fml.types.collection.IObservable|nil
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local frecency = props.frecency ---@type fml.types.collection.IFrecency|nil
  local input_keymaps = props.input_keymaps or {} ---@type fml.types.IKeymap[]
  local main_keymaps = props.main_keymaps or {} ---@type fml.types.IKeymap[]
  local preview_keymaps = props.preview_keymaps or {} ---@type fml.types.IKeymap[]

  local select = Select.new({
    title = "Find files",
    items = select_items,
    statusline_items = statusline_items,
    case_sensitive = case_sensitive,
    input = input,
    input_history = input_history,
    frecency = frecency,
    render_item = function(select_item, match)
      return self:render_item(select_item, match)
    end,
    input_keymaps = input_keymaps,
    main_keymaps = main_keymaps,
    preview_keymaps = preview_keymaps,
    width = 0.4,
    height = 0.8,
    width_preview = 0.45,
    max_height = 1,
    max_width = 1,
    fetch_preview_data = function(item)
      return self:fetch_preview_data(item)
    end,
    on_confirm = function(item)
      return self:open_filepath(item)
    end,
  })

  self.cwd = cwd
  self.item_map = item_map
  self._select = select

  return self
end

---@param item                         fml.types.ui.select.IItem
---@return fml.ui.search.preview.IData
function M:fetch_preview_data(item)
  local item_data = self.item_map[item.uuid] ---@type fml.types.ui.file_select.IItem|nil
  if item_data == nil then
    local lines = { "  Cannot retrieve the item by uuid=" .. item.uuid } ---@type string[]
    local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type fml.types.ui.IHighlight[]

    ---@type fml.ui.search.preview.IData
    return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
  end

  local filepath = path.join(self.cwd, item_data.filepath) ---@type string
  local filename = path.basename(filepath) ---@type string
  local is_text_file = is.printable_file(filename) ---@type boolean
  if is_text_file then
    local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil
    local lines = fs.read_file_as_lines({ filepath = filepath, max_lines = 300, silent = true }) ---@type string[]

    ---@type fml.ui.search.preview.IData
    return {
      lines = lines,
      highlights = {},
      filetype = filetype,
      title = item_data.filepath,
      lnum = item_data.lnum,
      col = item_data.col,
    }
  end

  local lines = { "  Not a text file, cannot preview." } ---@type string[]
  local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type fml.types.ui.IHighlight[]

  ---@type fml.ui.search.preview.IData
  return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
end

---@param item                         fml.types.ui.select.IItem
---@return boolean
function M:open_filepath(item)
  local item_data = self.item_map[item.uuid] ---@type fml.types.ui.file_select.IItem|nil
  local winnr = api_state.win_history:present() ---@type integer
  if item_data ~= nil and winnr ~= nil then
    local filepath = path.join(self.cwd, item_data.filepath) ---@type string
    vim.schedule(function()
      api_buf.open(winnr, filepath)
    end)
    return true
  end
  return false
end

---@param select_item                   fml.types.ui.select.IItem
---@param match                         fml.types.ui.select.ILineMatch
---@return string
---@return fml.types.ui.IInlineHighlight[]
function M:render_item(select_item, match)
  local item = self.item_map[select_item.uuid] ---@type fml.types.ui.file_select.IItem|nil
  if item ~= nil then
    local icon_width = string.len(item.icon) ---@type integer
    local text = item.icon .. item.filepath ---@type string

    ---@type fml.types.ui.IInlineHighlight[]
    local highlights = { { coll = 0, colr = icon_width, hlname = item.icon_hl } }
    for _, piece in ipairs(match.pieces) do
      ---@type fml.types.ui.IInlineHighlight
      local highlight = { coll = piece.l + icon_width, colr = piece.r + icon_width, hlname = "f_us_main_match" }
      table.insert(highlights, highlight)
    end
    return text, highlights
  end
  return select_item.text, {}
end

---@return integer|nil
function M:get_winnr_main()
  return self._select:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  return self._select:get_winnr_input()
end

---@return integer|nil
function M:get_winnr_preview()
  return self._select:get_winnr_preview()
end

---@param cwd                           string
---@param items                         fml.types.ui.file_select.IRawItem[]
---@return nil
function M:update_data(cwd, items)
  ---@type fml.types.ui.select.IItem[], table<string, fml.types.ui.file_select.IItem>
  local select_items, item_map = cook_items(items)

  self.cwd = cwd
  self.item_map = item_map
  self._select:update_data(select_items)
end

---@return nil
function M:close()
  self._select:close()
end

---@return nil
function M:focus()
  self._select:focus()
end

---@return nil
function M:open()
  self._select:open()
end

---@return nil
function M:toggle()
  self._select:toggle()
end

return M
