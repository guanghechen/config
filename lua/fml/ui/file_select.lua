local fs = require("fml.std.fs")
local is = require("fml.std.is")
local path = require("fml.std.path")
local util = require("fml.std.util")
local api_state = require("fml.api.state")
local api_buf = require("fml.api.buf")
local Select = require("fml.ui.select")

---@param items                         fml.types.ui.file_select.IItem[]
---@return fml.types.ui.select.IItem[]
local function resolve_select_items(items)
  local select_items = {} ---@type fml.types.ui.select.IItem[]
  for _, item in ipairs(items) do
    ---@type fml.types.ui.select.IItem
    local select_item = {
      group = item.group,
      uuid = item.uuid,
      display = item.filepath,
      lower = item.filepath:lower(),
    }
    table.insert(select_items, select_item)
  end
  return select_items
end

---@param params                        fml.types.ui.select.main.IRenderLineParams
---@return string
---@return fml.types.ui.IInlineHighlight[]
local function render_filepath(params)
  local match = params.match ---@type fml.types.ui.select.ILineMatch
  local item = params.item ---@type fml.types.ui.select.IItem

  ---@diagnostic disable-next-line: cast-type-mismatch
  ---@cast item fml.types.ui.select.IFileItem

  local filename = item.filename ---@type string|nil
  local icon = item.icon ---@type string|nil
  local icon_hl = item.icon_hl ---@type string|nil

  if filename == nil or icon == nil or icon_hl == nil then
    filename = path.basename(item.display)
    icon, icon_hl = util.calc_fileicon(filename)
    icon = icon .. " "

    item.filename = filename
    item.icon = icon
    item.icon_hl = icon_hl
  end

  local icon_width = string.len(icon) ---@type integer
  local text = icon .. item.display ---@type string

  ---@type fml.types.ui.IInlineHighlight[]
  local highlights = { { coll = 0, colr = icon_width, hlname = icon_hl } }
  for _, piece in ipairs(match.pieces) do
    ---@type fml.types.ui.IInlineHighlight
    local highlight = { coll = piece.l + icon_width, colr = piece.r + icon_width, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return text, highlights
end

---@class fml.ui.FileSelect : fml.types.ui.IFileSelect
---@field public cwd                    string
---@field public item_map               table<string, fml.types.ui.file_select.IItem>
---@field protected _select             fml.types.ui.ISelect
local M = {}
M.__index = M

---@class fml.ui.file_select.IProps
---@field public cwd                    string
---@field public title                  string
---@field public items                  fml.types.ui.file_select.IItem[]
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

  local _cwd = props.cwd ---@type string
  local _items = props.items ---@type fml.types.ui.file_select.IItem[]
  local _item_map = {} ---@type table<string, fml.types.ui.file_select.IItem>
  for _, item in ipairs(_items) do
    _item_map[item.uuid] = item
  end

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
    items = resolve_select_items(_items),
    statusline_items = statusline_items,
    case_sensitive = case_sensitive,
    input = input,
    input_history = input_history,
    frecency = frecency,
    render_line = render_filepath,
    input_keymaps = input_keymaps,
    main_keymaps = main_keymaps,
    preview_keymaps = preview_keymaps,
    width = 0.4,
    height = 0.8,
    width_preview = 0.45,
    max_height = 1,
    max_width = 1,
    fetch_preview_data = function(item)
      local item_data = self.item_map[item.uuid] ---@type fml.types.ui.file_select.IItem|nil
      if item_data == nil then
        local lines = { "  Cannot retrieve the item by uuid=" .. item.uuid } ---@type string[]
        local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type fml.types.ui.IHighlight[]

        ---@type fml.ui.search.preview.IData
        return {
          lines = lines,
          highlights = highlights,
          filetype = nil,
          title = item.display,
        }
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
      return {
        lines = lines,
        highlights = highlights,
        filetype = nil,
        title = item.display,
      }
    end,
    on_confirm = function(item)
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
    end,
  })

  self.cwd = _cwd
  self.item_map = _item_map
  self._select = select

  return self
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
---@param items                         fml.types.ui.file_select.IItem[]
---@return nil
function M:update_data(cwd, items)
  local item_map = {} ---@type table<string, fml.types.ui.file_select.IItem>
  for _, item in ipairs(items) do
    item_map[item.uuid] = item
  end

  local select_items = resolve_select_items(items) ---@type fml.types.ui.select.IItem[]

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
