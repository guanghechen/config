local fs = require("fml.std.fs")
local is = require("fml.std.is")
local path = require("fml.std.path")
local util = require("fml.std.util")
local api_state = require("fml.api.state")
local api_buf = require("fml.api.buf")
local Select = require("fml.ui.select")

---@class fml.ui.FileSelect : fml.types.ui.IFileSelect
---@field public cwd                    string
---@field protected _provider           fml.types.ui.select.IProvider
---@field protected _select             fml.types.ui.ISelect
local M = {}
M.__index = M

---@class fml.ui.file_select.IProps
---@field public case_sensitive         ?fml.types.collection.IObservable
---@field public cmp                    ?fml.types.ui.select.IMatchedItemCmp
---@field public destroy_on_close       boolean
---@field public enable_preview         boolean
---@field public frecency               ?fml.types.collection.IFrecency
---@field public input                  ?fml.types.collection.IObservable
---@field public input_history          ?fml.types.collection.IHistory
---@field public input_keymaps          ?fml.types.IKeymap[]
---@field public main_keymaps           ?fml.types.IKeymap[]
---@field public preview_keymaps        ?fml.types.IKeymap[]
---@field public provider               fml.types.ui.file_select.IProvider
---@field public statusline_items       ?fml.types.ui.search.IRawStatuslineItem[]
---@field public title                  string
---@field public on_close               ?fml.types.ui.search.IOnClose
---@field public on_confirm             ?fml.types.ui.select.IOnConfirm
---@field public on_preview_rendered    ?fml.types.ui.search.IOnPreviewRendered

---@param props fml.ui.file_select.IProps
---@return fml.ui.FileSelect
function M.new(props)
  local self = setmetatable({}, M)

  local case_sensitive = props.case_sensitive ---@type fml.types.collection.IObservable|nil
  local cmp = props.cmp ---@type fml.types.ui.select.IMatchedItemCmp|nil
  local destroy_on_close = props.destroy_on_close ---@type boolean
  local enable_preview = props.enable_preview ---@type boolean
  local frecency = props.frecency ---@type fml.types.collection.IFrecency|nil
  local input = props.input ---@type fml.types.collection.IObservable|nil
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local input_keymaps = props.input_keymaps or {} ---@type fml.types.IKeymap[]
  local main_keymaps = props.main_keymaps or {} ---@type fml.types.IKeymap[]
  local preview_keymaps = props.preview_keymaps or {} ---@type fml.types.IKeymap[]
  local provider = props.provider ---@type fml.types.ui.file_select.IProvider
  local statusline_items = props.statusline_items ---@type fml.types.ui.search.IRawStatuslineItem[]|nil
  local title = props.title ---@type string
  local on_close_from_props = props.on_close ---@type fml.types.ui.search.IOnClose|nil
  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.select.IOnConfirm|nil
  local on_preview_rendered = props.on_preview_rendered ---@type fml.types.ui.search.IOnPreviewRendered|nil

  ---@type fml.types.ui.select.IProvider
  local file_select_provider = {
    fetch_data = function()
      local raw_data = provider.fetch_data() ---@type fml.types.ui.file_select.IData
      local next_cwd = raw_data.cwd ---@type string
      local raw_items = raw_data.items ---@type fml.types.ui.file_select.IRawItem[]
      local present_uuid = raw_data.present_uuid ---@type string|nil

      local items = {} ---@type fml.types.ui.file_select.IItem[]
      for _, raw_item in ipairs(raw_items) do
        local filepath = raw_item.filepath ---@type string
        local filename = path.basename(raw_item.filepath)
        local icon, icon_hl = util.calc_fileicon(filename)

        ---@type fml.types.ui.file_select.IItem
        local item = {
          group = filepath,
          uuid = raw_item.uuid or filepath,
          text = filepath,
          data = {
            filepath = filepath,
            filename = filename,
            icon = icon .. " ",
            icon_hl = icon_hl,
            lnum = raw_item.lnum,
            col = raw_item.col,
          },
        }
        table.insert(items, item)
      end

      self.cwd = next_cwd

      ---@type fml.types.ui.select.IData
      return { items = items, present_uuid = present_uuid }
    end,
    fetch_preview_data = enable_preview and function(item)
      return self:fetch_preview_data(item)
    end or nil,
    patch_preview_data = enable_preview and function(item, last_item, last_data)
      return self:patch_preview_data(item, last_item, last_data)
    end or nil,
    render_item = provider.render_item or function(item, match)
      ---@cast item fml.types.ui.file_select.IItem
      return self:render_item(item, match)
    end,
  }

  ---@type fml.types.ui.search.IRawDimension

  local dimension = {
    height = 0.8,
    max_height = 1,
    max_width = 1,
    width = enable_preview and 0.4 or 0.5,
    width_preview = enable_preview and 0.45 or 0,
  }

  local select = Select.new({
    case_sensitive = case_sensitive,
    cmp = cmp,
    destroy_on_close = destroy_on_close,
    dimension = dimension,
    enable_preview = enable_preview,
    frecency = frecency,
    input = input,
    input_history = input_history,
    input_keymaps = input_keymaps,
    main_keymaps = main_keymaps,
    preview_keymaps = preview_keymaps,
    provider = file_select_provider,
    statusline_items = statusline_items,
    title = title,
    on_close = on_close_from_props,
    on_confirm = on_confirm_from_props or function(item)
      return self:open_filepath(item.data.filepath)
    end,
    on_preview_rendered = on_preview_rendered,
  })

  self.cwd = path.cwd() ---! initial cwd
  self._provider = file_select_provider
  self._select = select

  return self
end

---@param filepaths                     string[]
---@return fml.types.ui.file_select.IRawItem[]
function M.mark_items_by_filepaths(filepaths)
  ---@type fml.types.ui.file_select.IRawItem[]
  local items = {}
  for _, filepath in ipairs(filepaths) do
    ---@type fml.types.ui.file_select.IRawItem
    local item = { filepath = filepath }
    table.insert(items, item)
  end
  return items
end

---@param item                          fml.types.ui.file_select.IItem
---@return fml.ui.search.preview.IData
function M:fetch_preview_data(item)
  local filepath = path.join(self.cwd, item.data.filepath) ---@type string
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
      title = item.data.filepath,
      lnum = item.data.lnum,
      col = item.data.col,
    }
  end

  local lines = { "  Not a text file, cannot preview." } ---@type string[]
  local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type fml.types.ui.IHighlight[]

  ---@type fml.ui.search.preview.IData
  return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
end

---@param item                          fml.types.ui.file_select.IItem
---@param last_item                     fml.types.ui.file_select.IItem
---@param last_data                     fml.ui.search.preview.IData
---@diagnostic disable-next-line: unused-local
function M:patch_preview_data(item, last_item, last_data)
  ---@type fml.ui.search.preview.IData
  return {
    lines = last_data.lines,
    highlights = {},
    filetype = last_data.filetype,
    title = item.data.filepath,
    lnum = item.data.lnum,
    col = item.data.col,
  }
end

---@param filepath                      string
---@return boolean
function M:open_filepath(filepath)
  local winnr = api_state.win_history:present() ---@type integer
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    filepath = path.join(self.cwd, filepath) ---@type string
    vim.schedule(function()
      api_buf.open(winnr, filepath)
    end)
    return true
  end
  return false
end

---@param item                          fml.types.ui.file_select.IItem
---@param match                         fml.types.ui.select.IMatchedItem
---@return string
---@return fml.types.ui.IInlineHighlight[]
function M:render_item(item, match)
  local icon_width = string.len(item.data.icon) ---@type integer
  local text = item.data.icon .. item.data.filepath ---@type string

  ---@type fml.types.ui.IInlineHighlight[]
  local highlights = { { coll = 0, colr = icon_width, hlname = item.data.icon_hl } }
  for _, piece in ipairs(match.matches) do
    ---@type fml.types.ui.IInlineHighlight
    local highlight = { coll = piece.l + icon_width, colr = piece.r + icon_width, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return text, highlights
end

---@return nil
function M:mark_data_dirty()
  self._select:mark_data_dirty()
end

---@param dimension                     fml.types.ui.search.IRawDimension
---@return nil
function M:change_dimension(dimension)
  self._select:change_dimension(dimension)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  self._select:change_input_title(title)
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  self._select:change_preview_title(title)
end

---@return nil
function M:close()
  self._select:close()
end

---@return nil
function M:focus()
  self._select:focus()
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

---@return nil
function M:open()
  self._select:open()
end

---@return nil
function M:toggle()
  self._select:toggle()
end

return M
