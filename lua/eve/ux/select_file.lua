---@class eve.ux.IFileSelect : std.t.ux.IWidget
---@field public change_dimension       fun(self: eve.ux.IFileSelect, dimension: eve.ux.IRawSearchDimension): nil
---@field public change_input_title     fun(self: eve.ux.IFileSelect, title: string): nil
---@field public change_preview_title   fun(self: eve.ux.IFileSelect, title: string): nil
---@field public get_item               fun(self: eve.ux.IFileSelect, uuid: string): eve.ux.select.IItem|nil
---@field public get_matched_items      fun(self: eve.ux.IFileSelect): std.t.IScoredMatch[]
---@field public get_winnr_input        fun(self: eve.ux.IFileSelect): integer|nil
---@field public get_winnr_main         fun(self: eve.ux.IFileSelect): integer|nil
---@field public get_winnr_preview      fun(self: eve.ux.IFileSelect): integer|nil
---@field public mark_data_dirty        fun(self: eve.ux.IFileSelect): nil
---@field public mark_item_deleted      fun(self: eve.ux.IFileSelect, uuid: string): nil
---@field public reset_input            fun(self: eve.ux.IFileSelect, text: string): nil
---@field public toggle                 fun(self: eve.ux.IFileSelect): nil

---@alias eve.ux.select_file.IFetchData
---| fun(force: boolean): eve.ux.select_file.IData

---@alias eve.ux.select_file.IFetchPreviewData
---| fun(item: eve.ux.select_file.IItem): eve.ux.ISearchPreviewData|nil

---@alias eve.ux.select_file.IPatchPreviewData
---| fun(item: eve.ux.select_file.IItem, last_item: eve.ux.select_file.IItem, last_data: eve.ux.ISearchPreviewData): eve.ux.ISearchPreviewData

---@alias eve.ux.select_file.IRenderItem
---| fun(item: eve.ux.select_file.IItem, match: std.t.IScoredMatch): string, std.t.IHighlightInline[]

---@class eve.ux.select_file.IData
---@field public items                  eve.ux.select_file.IRawItem[]
---@field public uuid_present           ?string

---@class eve.ux.select_file.IRawItem
---@field public filepath               string
---@field public filepath_relative      string
---@field public group                  ?string
---@field public uuid                   ?string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class eve.ux.select_file.IItemData
---@field public filename               string
---@field public filepath               string
---@field public filepath_relative      string
---@field public icon                   string
---@field public icon_hl                string
---@field public lnum                   ?integer
---@field public col                    ?integer

---@class eve.ux.select_file.IItem : eve.ux.select.IItem
---@field public data                   eve.ux.select_file.IItemData

---@class eve.ux.select_file.IProvider
---@field public fetch_data             eve.ux.select_file.IFetchData
---@field public fetch_preview_data     ?eve.ux.select_file.IFetchPreviewData
---@field public patch_preview_data     ?eve.ux.select_file.IPatchPreviewData
---@field public render_item            ?eve.ux.select_file.IRenderItem

---@class eve.ux.FileSelect : eve.ux.IFileSelect
---@field protected _get_select         fun(): eve.ux.ISelect
local M = {}
M.__index = M

---@class eve.ux.IFileSelectProps
---@field public case_sensitive         ?std.collection.IObservable
---@field public cmp                    ?eve.ux.select.IMatchedItemCmp
---@field public delay_fetch            ?integer
---@field public delay_render           ?integer
---@field public dimension              ?eve.ux.IRawSearchDimension
---@field public dirty_on_invisible     ?boolean
---@field public preview_enabled        boolean
---@field public preview_wrap           ?boolean
---@field public extend_preset_keymaps  ?boolean
---@field public flag_fuzzy             ?std.collection.IObservable
---@field public flag_regex             ?std.collection.IObservable
---@field public flag_selected          ?std.collection.IObservable
---@field public frecency               ?std.collection.IFrecency
---@field public input                  ?std.collection.IObservable
---@field public input_history          ?std.collection.IHistory
---@field public input_keymaps          ?std.t.IKeymap[]
---@field public main_keymaps           ?std.t.IKeymap[]
---@field public multiple               ?boolean
---@field public permanent              ?boolean
---@field public preview_keymaps        ?std.t.IKeymap[]
---@field public provider               eve.ux.select_file.IProvider
---@field public statusline_items       ?std.t.ux.widget.IRawStatuslineItem[]
---@field public title                  string
---@field public on_close               ?eve.ux.search.IOnClose
---@field public on_confirm             ?eve.ux.select.IOnConfirm
---@field public on_preview_rendered    ?eve.ux.search.IOnPreviewRendered

---@param props eve.ux.IFileSelectProps
---@return eve.ux.FileSelect
function M.new(props)
  local self = setmetatable({}, M)

  local case_sensitive = props.case_sensitive ---@type std.collection.IObservable|nil
  local cmp = props.cmp ---@type eve.ux.select.IMatchedItemCmp|nil
  local delay_fetch = props.delay_fetch ---@type integer|nil
  local delay_render = props.delay_render ---@type integer|nil
  local dirty_on_invisible = props.dirty_on_invisible ---@type boolean|nil
  local preview_enabled = props.preview_enabled ---@type boolean
  local preview_wrap = props.preview_wrap ---@type boolean|nil
  local extend_preset_keymaps = props.extend_preset_keymaps ---@type boolean|nil
  local flag_fuzzy = props.flag_fuzzy ---@type std.collection.IObservable|nil
  local flag_regex = props.flag_regex ---@type std.collection.IObservable|nil
  local flag_selected = props.flag_selected ---@type std.collection.IObservable|nil
  local frecency = props.frecency ---@type std.collection.IFrecency|nil
  local input = props.input ---@type std.collection.IObservable|nil
  local input_history = props.input_history ---@type std.collection.IHistory|nil
  local input_keymaps = props.input_keymaps ---@type std.t.IKeymap[]|nil
  local main_keymaps = props.main_keymaps ---@type std.t.IKeymap[]|nil
  local multiple = props.multiple ---@type boolean|nil
  local permanent = props.permanent ---@type boolean|nil
  local preview_keymaps = props.preview_keymaps ---@type std.t.IKeymap[]|nil
  local provider = props.provider ---@type eve.ux.select_file.IProvider
  local statusline_items = props.statusline_items ---@type std.t.ux.widget.IRawStatuslineItem[]|nil
  local title = props.title ---@type string
  local on_close = props.on_close ---@type eve.ux.search.IOnClose|nil
  local on_confirm_from_props = props.on_confirm ---@type eve.ux.select.IOnConfirm|nil
  local on_preview_rendered = props.on_preview_rendered ---@type eve.ux.search.IOnPreviewRendered|nil

  local _select = nil ---@type eve.ux.ISelect|nil

  if extend_preset_keymaps then
    ---@return nil
    local function send_to_qflist()
      if _select ~= nil then
        local quickfix_items = {} ---@type std.t.IQuickFixItem[]
        local matched_items = _select:get_matched_items() ---@type std.t.IScoredMatch[]
        for _, matched_item in ipairs(matched_items) do
          local item = _select:get_item(matched_item.uuid) ---@type eve.ux.select.IItem|nil
          ---@cast item                 eve.ux.select_file.IItem

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

          eve.qflist.push(quickfix_items)
          eve.qflist.open_qflist(false)
        end
      end
    end

    ---@type std.t.IKeymap[]
    local common_keymaps = {
      {
        modes = { "i", "n", "v" },
        key = "<C-q>",
        callback = send_to_qflist,
        desc = "search: send to qflist",
      },
    }
    input_keymaps = vim.list_extend(vim.list_slice(common_keymaps), input_keymaps or {}) ---@type std.t.IKeymap[]
    main_keymaps = vim.list_extend(vim.list_slice(common_keymaps), main_keymaps or {}) ---@type std.t.IKeymap[]
    preview_keymaps = vim.list_extend(vim.list_slice(common_keymaps), preview_keymaps or {}) ---@type std.t.IKeymap[]
  end

  ---@type eve.ux.select.IProvider
  local select_provider = {
    fetch_data = function(force)
      local raw_data = provider.fetch_data(force) ---@type eve.ux.select_file.IData
      local raw_items = raw_data.items ---@type eve.ux.select_file.IRawItem[]
      local uuid_present = raw_data.uuid_present ---@type string|nil

      local items = {} ---@type eve.ux.select_file.IItem[]
      for _, raw_item in ipairs(raw_items) do
        local filepath = raw_item.filepath ---@type string
        local filepath_relative = raw_item.filepath_relative ---@type string
        local filename = std.path.basename(raw_item.filepath)
        local icon, icon_hl = eve.fn.fileicon(filename)

        ---@type eve.ux.select_file.IItem
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

      ---@type eve.ux.select.IData
      return { items = items, uuid_present = uuid_present }
    end,
    fetch_preview_data = preview_enabled and function(item)
      return self.fetch_preview_data(item)
    end or nil,
    patch_preview_data = preview_enabled and M.patch_preview_data or nil,
    render_item = provider.render_item or M.render_item,
  }

  local dimension_from_props = props.dimension or {} ---@type eve.ux.IRawSearchDimension

  ---@type eve.ux.IRawSearchDimension
  local dimension = {
    height = dimension_from_props.height or 0.8,
    max_height = dimension_from_props.max_height or 1,
    max_width = dimension_from_props.max_width or 1,
    row = dimension_from_props.row or 5,
    col = dimension_from_props.col,
    width = dimension_from_props.width or (preview_enabled and 0.4 or 0.5),
    width_preview = dimension_from_props.width_preview or (preview_enabled and 0.45 or 0),
  }

  ---@return eve.ux.ISelect
  local function get_select()
    if _select == nil then
      _select = eve.ux.Select.new({
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
        provider = select_provider,
        statusline_items = statusline_items,
        title = title,
        on_close = on_close,
        on_confirm = on_confirm_from_props or function(widget, items)
          local tabnr = vim.api.nvim_get_current_tabpage() ---@type integer
          local winnr_sourcefile = eve.tab.retrieve_winnr_sourcefile(tabnr) ---@type integer|nil
          if winnr_sourcefile ~= nil and vim.api.nvim_win_is_valid(winnr_sourcefile) then
            vim.api.nvim_tabpage_set_win(tabnr, winnr_sourcefile)
          end

          widget:close()
          for _, item in ipairs(items) do
            local filepath = item.data.filepath ---@type string
            eve.win.open_filepath(winnr_sourcefile, filepath, item.data.lnum, item.data.col)
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

---@param item                          eve.ux.select_file.IItem
---@return eve.ux.ISearchPreviewData
function M.fetch_preview_data(item)
  local filepath = item.data.filepath ---@type string
  local filename = item.data.filename ---@type string
  local is_text_file = eve.filetype.is_printable_file(filename) ---@type boolean
  if is_text_file then
    local filetype = vim.filetype.match({ filename = filename }) ---@type string|nil
    local lines = std.fs.read_file_as_lines({ filepath = filepath, silent = true }) ---@type string[]

    ---@type eve.ux.ISearchPreviewData
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
  local highlights = { { lnum = 1, coll = 0, colr = -1, hlname = "f_us_preview_error" } } ---@type std.t.IHighlight[]

  ---@type eve.ux.ISearchPreviewData
  return { lines = lines, highlights = highlights, filetype = nil, title = item.text }
end

---@param item                          eve.ux.select_file.IItem
---@param last_item                     eve.ux.select_file.IItem
---@param last_data                     eve.ux.ISearchPreviewData
---@diagnostic disable-next-line: unused-local
function M.patch_preview_data(item, last_item, last_data)
  ---@type eve.ux.ISearchPreviewData
  return {
    lines = last_data.lines,
    highlights = {},
    filetype = last_data.filetype,
    title = item.data.filepath_relative,
    lnum = item.data.lnum,
    col = item.data.col,
  }
end

---@param item                          eve.ux.select_file.IItem
---@param match                         std.t.IScoredMatch
---@return string
---@return std.t.IHighlightInline[]
function M.render_item(item, match)
  local icon_width = string.len(item.data.icon) ---@type integer
  local text = item.data.icon .. item.data.filepath_relative ---@type string

  if item.data.lnum ~= nil and item.data.col ~= nil then
    text = text .. ":" .. item.data.lnum .. ":" .. item.data.col
  end

  ---@type std.t.IHighlightInline[]
  local highlights = { { coll = 0, colr = icon_width, hlname = item.data.icon_hl } }
  for _, piece in ipairs(match.matches) do
    ---@type std.t.IHighlightInline
    local highlight = { coll = piece.l + icon_width, colr = piece.r + icon_width, hlname = "f_us_main_match" }
    table.insert(highlights, highlight)
  end
  return text, highlights
end

---@param dimension                     eve.ux.IRawSearchDimension
---@return nil
function M:change_dimension(dimension)
  local select = self._get_select() ---@type eve.ux.ISelect
  select:change_dimension(dimension)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  local select = self._get_select() ---@type eve.ux.ISelect
  select:change_input_title(title)
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  local select = self._get_select() ---@type eve.ux.ISelect
  select:change_preview_title(title)
end

---@return nil
function M:close()
  local select = self._get_select() ---@type eve.ux.ISelect
  select:close()
end

---@return nil
function M:focus()
  local select = self._get_select() ---@type eve.ux.ISelect
  select:focus()
end

---@return nil
function M:hide()
  local select = self._get_select() ---@type eve.ux.ISelect
  select:hide()
end

---@return boolean
function M:isdisposed()
  local select = self._get_select() ---@type eve.ux.ISelect
  return select:isdisposed()
end

---@return boolean
function M:isfocused()
  local select = self._get_select() ---@type eve.ux.ISelect
  return select:isfocused()
end

---@return boolean
function M:isvisible()
  local select = self._get_select() ---@type eve.ux.ISelect
  return select:isvisible()
end

---@param uuid                          string
---@return                              eve.ux.select.IItem|nil
function M:get_item(uuid)
  local select = self._get_select() ---@type eve.ux.ISelect
  return select:get_item(uuid)
end

---@return                              std.t.IScoredMatch[]
function M:get_matched_items()
  local select = self._get_select() ---@type eve.ux.ISelect
  return select:get_matched_items()
end

---@return integer|nil
function M:get_winnr_main()
  local select = self._get_select() ---@type eve.ux.ISelect
  return select:get_winnr_main()
end

---@return integer|nil
function M:get_winnr_input()
  local select = self._get_select() ---@type eve.ux.ISelect
  return select:get_winnr_input()
end

---@return integer|nil
function M:get_winnr_preview()
  local select = self._get_select() ---@type eve.ux.ISelect
  return select:get_winnr_preview()
end

---@return nil
function M:mark_data_dirty()
  local select = self._get_select() ---@type eve.ux.ISelect
  select:mark_data_dirty()
end

---@param uuid                          string
---@return nil
function M:mark_item_deleted(uuid)
  local select = self._get_select() ---@type eve.ux.ISelect
  select:mark_item_deleted(uuid)
end

---@param cwd                           string
---@param filepaths                     string[]
---@return eve.ux.select_file.IRawItem[]
function M.make_items_by_filepaths(cwd, filepaths)
  local items = {} ---@type eve.ux.select_file.IRawItem[]
  for _, filepath in ipairs(filepaths) do
    local relative_filepath = std.path.relative(cwd, filepath, true) ---@type string
    ---@type eve.ux.select_file.IRawItem
    local item = {
      filepath = filepath,
      filepath_relative = relative_filepath,
    }
    table.insert(items, item)
  end
  return items
end

---@return nil
function M:resize()
  local select = self._get_select() ---@type eve.ux.ISelect
  select:resize()
end

---@return nil
function M:toggle()
  local select = self._get_select() ---@type eve.ux.ISelect
  select:toggle()
end

---@param text                          string
---@return nil
function M:reset_input(text)
  local select = self._get_select() ---@type eve.ux.ISelect
  select:reset_input(text)
end

return M
