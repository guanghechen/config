local ft = require("eve.constant.filetype")
local editor = require("eve.module.editor")
local calc_fileicon = require("eve.module.fileicon").calc_fileicon
local state = require("eve.state")

local Select = require("fml.ux.select")

---@class fml.ux.IFileSelect : eve.t.ux.IWidget
---@field public change_dimension       fun(self: fml.ux.IFileSelect, dimension: fml.ux.search.IRawDimension): nil
---@field public change_input_title     fun(self: fml.ux.IFileSelect, title: string): nil
---@field public change_preview_title   fun(self: fml.ux.IFileSelect, title: string): nil
---@field public get_item               fun(self: fml.ux.IFileSelect, uuid: string): fml.ux.select.IItem|nil
---@field public get_matched_items      fun(self: fml.ux.IFileSelect): fml.ux.select.IMatchedItem[]
---@field public get_winnr_input        fun(self: fml.ux.IFileSelect): integer|nil
---@field public get_winnr_main         fun(self: fml.ux.IFileSelect): integer|nil
---@field public get_winnr_preview      fun(self: fml.ux.IFileSelect): integer|nil
---@field public mark_data_dirty        fun(self: fml.ux.IFileSelect): nil
---@field public mark_item_deleted      fun(self: fml.ux.IFileSelect, uuid: string): nil
---@field public show                   fun(self: fml.ux.IFileSelect): nil
---@field public toggle                 fun(self: fml.ux.IFileSelect): nil

---@alias fml.ux.file_select.IFetchData
---| fun(force: boolean): fml.ux.file_select.IData

---@alias fml.ux.file_select.IFetchPreviewData
---| fun(item: fml.ux.file_select.IItem): fml.ux.search.preview.IData|nil

---@alias fml.ux.file_select.IPatchPreviewData
---| fun(item: fml.ux.file_select.IItem, last_item: fml.ux.file_select.IItem, last_data: fml.ux.search.preview.IData): fml.ux.search.preview.IData

---@alias fml.ux.file_select.IRenderItem
---| fun(item: fml.ux.file_select.IItem, match: fml.ux.select.IMatchedItem): string, eve.t.IHighlightInline[]

---@class fml.ux.file_select.IData
---@field public items                  fml.ux.file_select.IRawItem[]
---@field public uuid_present           ?string

---@class fml.ux.file_select.IRawItem
---
---@field public filepath               string
---@field public filepath_relative      string
---@field public group                  ?string
---@field public uuid                   ?string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.ux.file_select.IItemData
---@field public filename               string
---@field public filepath               string
---@field public filepath_relative      string
---@field public icon                   string
---@field public icon_hl                string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class fml.ux.file_select.IItem : fml.ux.select.IItem
---@field public data                   fml.ux.file_select.IItemData

---@class fml.ux.file_select.IProvider
---@field public fetch_data             fml.ux.file_select.IFetchData
---@field public fetch_preview_data     ?fml.ux.file_select.IFetchPreviewData
---@field public patch_preview_data     ?fml.ux.file_select.IPatchPreviewData
---@field public render_item            ?fml.ux.file_select.IRenderItem

---@class fml.ux.FileSelect : fml.ux.IFileSelect
---@field protected _get_select         fun(): fml.ux.ISelect
local M = {}
M.__index = M

---@class fml.ux.file_select.IProps
---@field public case_sensitive         ?eve.collection.IObservable -- boolean>
---@field public cmp                    ?fml.ux.select.IMatchedItemCmp
---@field public delay_fetch            ?integer
---@field public delay_render           ?integer
---@field public dimension              ?fml.ux.search.IRawDimension
---@field public dirty_on_invisible     ?boolean
---@field public preview_enabled        boolean
---@field public preview_wrap           ?boolean
---@field public extend_preset_keymaps  ?boolean
---@field public flag_fuzzy             ?eve.collection.IObservable -- boolean>
---@field public flag_regex             ?eve.collection.IObservable -- boolean>
---@field public flag_selected          ?eve.collection.IObservable -- boolean>
---@field public frecency               ?eve.collection.IFrecency
---@field public input                  ?eve.collection.IObservable -- string>
---@field public input_history          ?eve.collection.IHistory
---@field public input_keymaps          ?eve.t.IKeymap[]
---@field public main_keymaps           ?eve.t.IKeymap[]
---@field public multiple               ?boolean
---@field public permanent              ?boolean
---@field public preview_keymaps        ?eve.t.IKeymap[]
---@field public provider               fml.ux.file_select.IProvider
---@field public statusline_items       ?eve.t.ux.widget.IRawStatuslineItem[]
---@field public title                  string
---@field public on_close               ?fml.ux.search.IOnClose
---@field public on_confirm             ?fml.ux.select.IOnConfirm
---@field public on_preview_rendered    ?fml.ux.search.IOnPreviewRendered

---@param props fml.ux.file_select.IProps
---@return fml.ux.FileSelect
function M.new(props)
  local self = setmetatable({}, M)

  local case_sensitive = props.case_sensitive ---@type eve.collection.IObservable -- boolean>|nil
  local cmp = props.cmp ---@type fml.ux.select.IMatchedItemCmp|nil
  local delay_fetch = props.delay_fetch ---@type integer|nil
  local delay_render = props.delay_render ---@type integer|nil
  local dirty_on_invisible = props.dirty_on_invisible ---@type boolean|nil
  local preview_enabled = props.preview_enabled ---@type boolean
  local preview_wrap = props.preview_wrap ---@type boolean|nil
  local extend_preset_keymaps = props.extend_preset_keymaps ---@type boolean|nil
  local flag_fuzzy = props.flag_fuzzy ---@type eve.collection.IObservable -- boolean>|nil
  local flag_regex = props.flag_regex ---@type eve.collection.IObservable -- boolean>|nil
  local flag_selected = props.flag_selected ---@type eve.collection.IObservable -- boolean>|nil
  local frecency = props.frecency ---@type eve.collection.IFrecency|nil
  local input = props.input ---@type eve.collection.IObservable -- string>|nil
  local input_history = props.input_history ---@type eve.collection.IHistory|nil
  local input_keymaps = props.input_keymaps ---@type eve.t.IKeymap[]|nil
  local main_keymaps = props.main_keymaps ---@type eve.t.IKeymap[]|nil
  local multiple = props.multiple ---@type boolean|nil
  local permanent = props.permanent ---@type boolean|nil
  local preview_keymaps = props.preview_keymaps ---@type eve.t.IKeymap[]|nil
  local provider = props.provider ---@type fml.ux.file_select.IProvider
  local statusline_items = props.statusline_items ---@type eve.t.ux.widget.IRawStatuslineItem[]|nil
  local title = props.title ---@type string
  local on_close = props.on_close ---@type fml.ux.search.IOnClose|nil
  local on_confirm_from_props = props.on_confirm ---@type fml.ux.select.IOnConfirm|nil
  local on_preview_rendered = props.on_preview_rendered ---@type fml.ux.search.IOnPreviewRendered|nil

  local _select = nil ---@type fml.ux.ISelect|nil

  if extend_preset_keymaps then
    ---@return nil
    local function send_to_qflist()
      if _select ~= nil then
        local quickfix_items = {} ---@type eve.t.IQuickFixItem[]
        local matched_items = _select:get_matched_items() ---@type fml.ux.select.IMatchedItem[]
        for _, matched_item in ipairs(matched_items) do
          local item = _select:get_item(matched_item.uuid) ---@type fml.ux.select.IItem|nil
          ---@cast item                 fml.ux.file_select.IItem

          if item ~= nil then
            table.insert(quickfix_items, {
              filename = item.data.filepath_relative,
              lnum = item.data.lnum or 1,
              col = item.data.col or 0,
            })
          end
        end

        if #quickfix_items > 0 then
          _select:close()

          state.qflist.push(quickfix_items)
          state.qflist.open_qflist(false)
        end
      end
    end

    ---@type eve.t.IKeymap[]
    local common_keymaps = {
      {
        modes = { "i", "n", "v" },
        key = "<C-q>",
        callback = send_to_qflist,
        desc = "search: send to qflist",
      },
    }
    input_keymaps = vim.list_extend(vim.list_slice(common_keymaps), input_keymaps or {}) ---@type eve.t.IKeymap[]
    main_keymaps = vim.list_extend(vim.list_slice(common_keymaps), main_keymaps or {}) ---@type eve.t.IKeymap[]
    preview_keymaps = vim.list_extend(vim.list_slice(common_keymaps), preview_keymaps or {}) ---@type eve.t.IKeymap[]
  end

  ---@type fml.ux.select.IProvider
  local file_select_provider = {
    fetch_data = function(force)
      local raw_data = provider.fetch_data(force) ---@type fml.ux.file_select.IData
      local raw_items = raw_data.items ---@type fml.ux.file_select.IRawItem[]
      local uuid_present = raw_data.uuid_present ---@type string|nil

      local items = {} ---@type fml.ux.file_select.IItem[]
      for _, raw_item in ipairs(raw_items) do
        local filepath = raw_item.filepath ---@type string
        local filepath_relative = raw_item.filepath_relative ---@type string
        local filename = eve.path.basename(raw_item.filepath)
        local icon, icon_hl = calc_fileicon(filename)

        ---@type fml.ux.file_select.IItem
        local item = {
          group = raw_item.group or filepath,
          uuid = raw_item.uuid or filepath,
          text = filepath_relative,
          data = {
            filename = filename,
            filepath = filepath,
            filepath_relative = filepath_relative,
            icon = icon .. " ",
            icon_hl = icon_hl,
            lnum = raw_item.lnum,
            col = raw_item.col,
          },
        }
        table.insert(items, item)
      end

      ---@type fml.ux.select.IData
      return { items = items, uuid_present = uuid_present }
    end,
    fetch_preview_data = preview_enabled and function(item)
      return self.fetch_preview_data(item)
    end or nil,
    patch_preview_data = preview_enabled and M.patch_preview_data or nil,
    render_item = provider.render_item or M.render_item,
  }

  local dimension_from_props = props.dimension or {} ---@type fml.ux.search.IRawDimension

  ---@type fml.ux.search.IRawDimension
  local dimension = {
    height = dimension_from_props.height or 0.8,
    max_height = dimension_from_props.max_height or 1,
    max_width = dimension_from_props.max_width or 1,
    row = dimension_from_props.row or 5,
    col = dimension_from_props.col,
    width = dimension_from_props.width or (preview_enabled and 0.4 or 0.5),
    width_preview = dimension_from_props.width_preview or (preview_enabled and 0.45 or 0),
  }

  ---@return fml.ux.ISelect
  local function get_select()
    if _select == nil then
      _select = Select.new({
        case_sensitive = case_sensitive,
        cmp = cmp,
        delay_fetch = delay_fetch,
        delay_render = delay_render,
        dimension = dimension,
        dirty_on_invisible = dirty_on_invisible,
        preview_enabled = preview_enabled,
        preview_wrap = preview_wrap,
        extend_preset_keymaps = extend_preset_keymaps,
        flag_fuzzy = flag_fuzzy,
        flag_regex = flag_regex,
        flag_selected = flag_selected,
        frecency = frecency,
        input = input,
        input_history = input_history,
        input_keymaps = input_keymaps,
        main_keymaps = main_keymaps,
        multiple = multiple,
        permanent = permanent,
        preview_keymaps = preview_keymaps,
        provider = file_select_provider,
        statusline_items = statusline_items,
        title = title,
        on_close = on_close,
        on_confirm = on_confirm_from_props or function(widget, items)
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = state.tab.get_winnr_sourcefile(tabnr) ---@type integer|nil
          widget:close()

          for _, item in ipairs(items) do
            local filepath = item.data.filepath ---@type string
            editor.open_filepath(winnr_sourcefile, filepath, item.data.lnum, item.data.col)
          end
        end,
        on_preview_rendered = on_preview_rendered,
      })
    end
    return _select
  end

  self._get_select = get_select
  return self
end

---@param item                          fml.ux.file_select.IItem
---@return fml.ux.search.preview.IData
function M.fetch_preview_data(item)
  local filepath = item.data.filepath ---@type string
  local filename = item.data.filename ---@type string
  local is_text_file = ft.is_printable_file(filename) ---@type boolean
  if is_text_file then
    local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil
    local lines = eve.fs.read_file_as_lines({ filepath = filepath, silent = true }) ---@type string[]

    ---@type fml.ux.search.preview.IData
    return {
      lines = lines,
      highlights = {},
      filetype = filetype,
      title = item.data.filepath_relative,
      lnum = item.data.lnum,
      col = item.data.col,
    }
  end

  local lines = { "  Not a text file, cannot preview." } ---@type string[]
  local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type eve.t.IHighlight[]

  ---@type fml.ux.search.preview.IData
  return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
end

---@param item                          fml.ux.file_select.IItem
---@param last_item                     fml.ux.file_select.IItem
---@param last_data                     fml.ux.search.preview.IData
---@diagnostic disable-next-line: unused-local
function M.patch_preview_data(item, last_item, last_data)
  ---@type fml.ux.search.preview.IData
  return {
    lines = last_data.lines,
    highlights = {},
    filetype = last_data.filetype,
    title = item.data.filepath_relative,
    lnum = item.data.lnum,
    col = item.data.col,
  }
end

---@param item                          fml.ux.file_select.IItem
---@param match                         fml.ux.select.IMatchedItem
---@return string
---@return eve.t.IHighlightInline[]
function M.render_item(item, match)
  local icon_width = string.len(item.data.icon) ---@type integer
  local text = item.data.icon .. item.data.filepath_relative ---@type string

  if item.data.lnum ~= nil and item.data.col ~= nil then
    text = text .. ":" .. item.data.lnum .. ":" .. item.data.col
  end

  ---@type eve.t.IHighlightInline[]
  local highlights = { { coll = 0, colr = icon_width, hlname = item.data.icon_hl } }
  for _, piece in ipairs(match.matches) do
    ---@type eve.t.IHighlightInline
    local highlight = { coll = piece.l + icon_width, colr = piece.r + icon_width, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return text, highlights
end

---@param dimension                     fml.ux.search.IRawDimension
---@return nil
function M:change_dimension(dimension)
  local select = self._get_select() ---@type fml.ux.ISelect
  select:change_dimension(dimension)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  local select = self._get_select() ---@type fml.ux.ISelect
  select:change_input_title(title)
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  local select = self._get_select() ---@type fml.ux.ISelect
  select:change_preview_title(title)
end

---@return nil
function M:close()
  local select = self._get_select() ---@type fml.ux.ISelect
  select:close()
end

---@return nil
function M:focus()
  local select = self._get_select() ---@type fml.ux.ISelect
  select:focus()
end

---@return boolean
function M:focused()
  local select = self._get_select() ---@type fml.ux.ISelect
  return select:focused()
end

---@param uuid                          string
---@return                              fml.ux.select.IItem|nil
function M:get_item(uuid)
  local select = self._get_select() ---@type fml.ux.ISelect
  return select:get_item(uuid)
end

---@return                              fml.ux.select.IMatchedItem[]
function M:get_matched_items()
  local select = self._get_select() ---@type fml.ux.ISelect
  return select:get_matched_items()
end

---@return integer|nil
function M:get_winnr_main()
  local select = self._get_select() ---@type fml.ux.ISelect
  return select:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  local select = self._get_select() ---@type fml.ux.ISelect
  return select:get_winnr_input()
end

---@return integer|nil
function M:get_winnr_preview()
  local select = self._get_select() ---@type fml.ux.ISelect
  return select:get_winnr_preview()
end

---@return nil
function M:mark_data_dirty()
  local select = self._get_select() ---@type fml.ux.ISelect
  select:mark_data_dirty()
end

---@param uuid                          string
---@return nil
function M:mark_item_deleted(uuid)
  local select = self._get_select() ---@type fml.ux.ISelect
  select:mark_item_deleted(uuid)
end

---@param cwd                           string
---@param filepaths                     string[]
---@return fml.ux.file_select.IRawItem[]
function M.make_items_by_filepaths(cwd, filepaths)
  local items = {} ---@type fml.ux.file_select.IRawItem[]
  for _, filepath in ipairs(filepaths) do
    local relative_filepath = eve.path.relative(cwd, filepath, true) ---@type string
    ---@type fml.ux.file_select.IRawItem
    local item = {
      filepath = filepath,
      filepath_relative = relative_filepath,
    }
    table.insert(items, item)
  end
  return items
end

---@return nil
function M:show()
  local select = self._get_select() ---@type fml.ux.ISelect
  select:show()
end

---@return nil
function M:toggle()
  local select = self._get_select() ---@type fml.ux.ISelect
  select:toggle()
end

return M
