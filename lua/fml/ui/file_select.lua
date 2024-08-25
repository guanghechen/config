local std_array = require("fml.std.array")
local fs = require("fml.std.fs")
local is = require("fml.std.is")
local path = require("fml.std.path")
local util = require("fml.std.util")
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
---@field public dimension              ?fml.types.ui.search.IRawDimension
---@field public dirty_on_close         ?boolean
---@field public enable_preview         boolean
---@field public extend_preset_keymaps  ?boolean
---@field public frecency               ?fml.types.collection.IFrecency
---@field public fuzzy                  ?fml.types.collection.IObservable
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

  ---@type fml.types.IKeymap[]
  local common_keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-q>",
      callback = function()
        self:send_to_qflist()
      end,
      desc = "search: send to qflist",
    },
  }
  local input_keymaps = std_array.concat(common_keymaps, props.input_keymaps or {}) ---@type fml.types.IKeymap[]
  local main_keymaps = std_array.concat(common_keymaps, props.main_keymaps or {}) ---@type fml.types.IKeymap[]
  local preview_keymaps = std_array.concat(common_keymaps, props.preview_keymaps or {}) ---@type fml.types.IKeymap[]

  local case_sensitive = props.case_sensitive ---@type fml.types.collection.IObservable|nil
  local cmp = props.cmp ---@type fml.types.ui.select.IMatchedItemCmp|nil
  local destroy_on_close = props.destroy_on_close ---@type boolean
  local dirty_on_close = not not props.dirty_on_close ---@type boolean|nil
  local enable_preview = props.enable_preview ---@type boolean
  local extend_preset_keymaps = props.extend_preset_keymaps ---@type boolean|nil
  local frecency = props.frecency ---@type fml.types.collection.IFrecency|nil
  local fuzzy = props.fuzzy ---@type fml.types.collection.IObservable|nil
  local input = props.input ---@type fml.types.collection.IObservable|nil
  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local provider = props.provider ---@type fml.types.ui.file_select.IProvider
  local statusline_items = props.statusline_items ---@type fml.types.ui.search.IRawStatuslineItem[]|nil
  local title = props.title ---@type string
  local on_close_from_props = props.on_close ---@type fml.types.ui.search.IOnClose|nil
  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.select.IOnConfirm|nil
  local on_preview_rendered = props.on_preview_rendered ---@type fml.types.ui.search.IOnPreviewRendered|nil

  ---@return nil
  local function on_close()
    if dirty_on_close then
      self:mark_data_dirty()
    end

    if on_close_from_props ~= nil then
      on_close_from_props()
    end
  end

  ---@type fml.types.ui.select.IProvider
  local file_select_provider = {
    fetch_data = function(force)
      local raw_data = provider.fetch_data(force) ---@type fml.types.ui.file_select.IData
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
      return self.fetch_preview_data(self.cwd, item)
    end or nil,
    patch_preview_data = enable_preview and M.patch_preview_data or nil,
    render_item = provider.render_item or M.render_item,
  }

  local dimension_from_props = props.dimension or {} ---@type fml.types.ui.search.IRawDimension

  ---@type fml.types.ui.search.IRawDimension
  local dimension = {
    height = dimension_from_props.height or 0.8,
    max_height = dimension_from_props.max_height or 1,
    max_width = dimension_from_props.max_width or 1,
    width = dimension_from_props.width or (enable_preview and 0.4 or 0.5),
    width_preview = dimension_from_props.width_preview or (enable_preview and 0.45 or 0),
  }

  local select = Select.new({
    case_sensitive = case_sensitive,
    cmp = cmp,
    destroy_on_close = destroy_on_close,
    dimension = dimension,
    enable_preview = enable_preview,
    extend_preset_keymaps = extend_preset_keymaps,
    frecency = frecency,
    fuzzy = fuzzy,
    input = input,
    input_history = input_history,
    input_keymaps = input_keymaps,
    main_keymaps = main_keymaps,
    preview_keymaps = preview_keymaps,
    provider = file_select_provider,
    statusline_items = statusline_items,
    title = title,
    on_close = on_close,
    on_confirm = on_confirm_from_props or function(item)
      local filepath = path.join(self.cwd, item.data.filepath) ---@type string
      return api_buf.open_in_current_valid_win(filepath)
    end,
    on_preview_rendered = on_preview_rendered,
  })

  self.cwd = path.cwd() ---! initial cwd
  self._provider = file_select_provider
  self._select = select

  return self
end

---@param cwd                           string
---@param item                          fml.types.ui.file_select.IItem
---@return fml.ui.search.preview.IData
function M.fetch_preview_data(cwd, item)
  local filepath = path.join(cwd, item.data.filepath) ---@type string
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
function M.patch_preview_data(item, last_item, last_data)
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

---@param item                          fml.types.ui.file_select.IItem
---@param match                         fml.types.ui.select.IMatchedItem
---@return string
---@return fml.types.ui.IInlineHighlight[]
function M.render_item(item, match)
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
function M:mark_data_dirty()
  self._select:mark_data_dirty()
end

---@param filepaths                     string[]
---@return fml.types.ui.file_select.IRawItem[]
function M.make_items_by_filepaths(filepaths)
  ---@type fml.types.ui.file_select.IRawItem[]
  local items = {}
  for _, filepath in ipairs(filepaths) do
    ---@type fml.types.ui.file_select.IRawItem
    local item = { filepath = filepath }
    table.insert(items, item)
  end
  return items
end

---@return nil
function M:open()
  self._select:open()
end

---@return nil
function M:send_to_qflist()
  local cwd = fml.path.cwd() ---@type string
  local select_cwd = self.cwd ---@type string
  local select = self._select ---@type fml.types.ui.ISelect
  local quickfix_items = {} ---@type fml.types.IQuickFixItem[]
  local matched_items = select:get_matched_items() ---@type fml.types.ui.select.IMatchedItem[]
  for _, matched_item in ipairs(matched_items) do
    local item = select:get_item(matched_item.uuid) ---@type fml.types.ui.select.IItem|nil
    ---@cast item fml.types.ui.file_select.IItem

    if item ~= nil then
      local absolute_filepath = fml.path.join(select_cwd, item.data.filepath) ---@type string
      local relative_filepath = fml.path.relative(cwd, absolute_filepath) ---@type string
      table.insert(quickfix_items, {
        filename = relative_filepath,
        lnum = item.data.lnum or 1,
        col = item.data.col or 0,
      })
    end
  end

  if #quickfix_items > 0 then
    vim.fn.setqflist(quickfix_items, "r")
    select:close()
    vim.cmd("copen")
  end
end

---@return nil
function M:toggle()
  self._select:toggle()
end

return M
