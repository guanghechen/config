local EDITING_PREFIX = eve.setting.EDITING_INPUT_PREFIX ---@type string

local highlights = {
  input = table.concat({
    "FloatBorder:f_us_border",
    "FloatTitle:f_us_input_title",
    "Normal:f_us_input_normal",
  }, ","),
  main = table.concat({
    "Cursor:f_us_main_current",
    "CursorColumn:f_us_main_current",
    "CursorLine:f_us_main_current",
    "CursorLineNr:f_us_main_current",
    "FloatBorder:f_us_border",
    "Normal:f_us_main_normal",
  }, ","),
  preview = table.concat({
    "Cursor:f_us_preview_current",
    "CursorColumn:f_us_preview_current",
    "CursorLine:f_us_preview_current",
    "CursorLineNr:f_us_preview_current",
    "FloatBorder:f_us_border",
    "FloatTitle:f_us_preview_title",
    "Normal:f_us_preview_normal",
  }, ","),
}

local borders = {
  -- stylua: ignore start
  input =               { "╭", "─", "╮", "│", "┤", "─", "├", "│" },
  input_with_preview =  { "╭", "─", "┬", "│", "┤", "─", "├", "│" },
  input_without_main =  { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
  main =                { "├", "─", "┤", "│", "╯", "─", "╰", "│" },
  main_with_preview =   { "├", "─", "┤", "│", "┴", "─", "╰", "│" },
  preview =             { "┬", "─", "╮", "│", "╯", "─", "┴", "│" },
  -- stylua: ignore end
}

---@class eve.ux.ISearch : eve.t.ux.IWidget
---@field public context                eve.ux.ISearchContext
---@field public change_input_title     fun(self: eve.ux.ISearch, title: string): nil
---@field public change_preview_title   fun(self: eve.ux.ISearch, title: string): nil
---@field public get_item_selected      fun(self: eve.ux.ISearch): eve.ux.search.IItem|nil, integer, string|nil
---@field public get_winnr_input        fun(self: eve.ux.ISearch): integer|nil
---@field public get_winnr_main         fun(self: eve.ux.ISearch): integer|nil
---@field public get_winnr_preview      fun(self: eve.ux.ISearch): integer|nil
---@field public mark_item_deleted      fun(self: eve.ux.ISearch, uuid: string): nil
---@field public reset_input            fun(self: eve.ux.ISearch, text: string): nil
---@field public show                   fun(self: eve.ux.ISearch): nil
---@field public toggle                 fun(self: eve.ux.ISearch): nil

---@alias eve.ux.search.IOnClose
---| fun(): nil

---@alias eve.ux.search.IOnConfirm
---| fun(widget: eve.ux.ISearch, items: eve.ux.search.IItem[]): nil

---@alias eve.ux.search.IOnInvisible
---| fun(): nil

---@alias eve.ux.search.IOnMainRendered
---| fun(): nil

---@alias eve.ux.search.IOnPreviewRendered
---| fun(): nil

---@alias eve.ux.search.IOnResume
---| fun(): nil

---@alias eve.ux.search.IFetchPreviewData
---| fun(item: eve.ux.search.IItem): eve.ux.ISearchPreviewData|nil

---@alias eve.ux.search.IPatchPreviewData
---| fun(item: eve.ux.search.IItem, last_item: eve.ux.search.IItem, last_data: eve.ux.ISearchPreviewData): eve.ux.ISearchPreviewData

---@alias eve.ux.search.IFetchDataCallback
---| fun(ok: true, data: eve.ux.search.IData|nil): nil
---| fun(ok: false, error: string|nil): nil

---@alias eve.ux.search.IFetchData
---| fun(input: string, force: boolean, callback: eve.ux.search.IFetchDataCallback): nil

---@class eve.ux.search.IData
---@field public items                  eve.ux.search.IItem[]
---@field public uuid_cursor            ?string
---@field public uuid_present           ?string

---@class eve.ux.search.IItem
---@field public group                  string|nil
---@field public parent                 string|nil
---@field public uuid                   string
---@field public text                   string
---@field public highlights             eve.t.IHighlightInline[]

---@class eve.ux.search.IProps
---@field public context                eve.ux.ISearchContext
---@field public delay_render           ?integer
---@field public fetch_preview_data     ?eve.ux.search.IFetchPreviewData
---@field public input_keymaps          ?eve.t.IKeymap[]
---@field public main_keymaps           ?eve.t.IKeymap[]
---@field public patch_preview_data     ?eve.ux.search.IPatchPreviewData
---@field public preview_keymaps        ?eve.t.IKeymap[]
---@field public statusline_items       eve.t.ux.widget.IRawStatuslineItem[]
---@field public on_close               ?eve.ux.search.IOnClose
---@field public on_invisible           ?eve.ux.search.IOnInvisible
---@field public on_confirm             eve.ux.search.IOnConfirm
---@field public on_preview_rendered    ?eve.ux.search.IOnPreviewRendered

---@class eve.ux.Search : eve.ux.ISearch
---@field protected _input              eve.ux.ISearchInput
---@field protected _main               eve.ux.ISearchMain
---@field protected _preview            eve.ux.ISearchPreview|nil
---@field protected _on_close           ?eve.ux.search.IOnClose
---@field protected _on_invisible       ?eve.ux.search.IOnInvisible
local M = {}
M.__index = M

---@param props                         eve.ux.search.IProps
---@return eve.ux.Search
function M.new(props)
  local self = setmetatable({}, M)

  local enable_preview = type(props.fetch_preview_data) == "function" ---@type boolean
  local context = props.context ---@type eve.ux.ISearchContext
  local common_keymaps = eve.state.widget.get_keymaps(self) ---@type eve.t.IKeymap[]
  local statusline_items = {} ---@type eve.t.ux.widget.IStatuslineItem[]
  local delay_render = math.max(0, props.delay_render or 48) ---@type integer

  local raw_statusline_items = props.statusline_items ---@type eve.t.ux.widget.IRawStatuslineItem[]
  local index = #raw_statusline_items > 0 and raw_statusline_items[1].type == "popup" and 0 or 1 ---@type integer
  for _, item in ipairs(raw_statusline_items) do
    if not item.disabled then
      local stl_state = item.state ---@type eve.std.collection.IObservable
      local symbol = item.symbol ---@type string
      local callback = item.callback ---@type fun(): nil
      local callback_fn = eve.G.register_anonymous_fn(callback) or "" ---@type string

      ---@type eve.t.ux.widget.IStatuslineItem
      local statusline_item = { type = item.type, state = stl_state, symbol = symbol, callback_fn = callback_fn }
      table.insert(statusline_items, statusline_item)

      ---@type eve.t.IKeymap
      local keymap = {
        modes = { "n", "v" },
        key = "<leader>" .. index,
        callback = callback,
        desc = item.desc,
        nowait = true,
      }
      table.insert(common_keymaps, keymap)
      index = index + 1
    end
  end

  local on_confirm_from_props = props.on_confirm ---@type eve.ux.search.IOnConfirm
  local on_close_from_props = props.on_close ---@type eve.ux.search.IOnClose|nil
  local on_invisible_from_props = props.on_invisible ---@type eve.ux.search.IOnInvisible|nil

  ---@return nil
  local function on_confirm()
    local selected_items = context:get_selected_items() ---@type eve.ux.search.IItem[]
    if #selected_items < 1 then
      local item = context:get_current() ---@type eve.ux.search.IItem|nil
      if item ~= nil then
        selected_items = { item } ---@type eve.ux.search.IItem[]
      end
    end

    if #selected_items > 0 then
      context:reset_selected_items()
      on_confirm_from_props(self, selected_items)

      local status = context.status:snapshot() ---@type eve.e.WidgetStatus
      if status ~= "visible" then
        local input_history = context.input_history ---@type eve.std.collection.IHistory|nil
        if input_history ~= nil then
          local top = input_history:top() ---@type string|nil
          if top ~= nil then
            top = eve.string.starts_with(top, EDITING_PREFIX) and top:sub(#EDITING_PREFIX + 1) or top ---@type string
            input_history:update_top(top)
          end
        end
      end
    end
  end

  ---@return nil
  local function on_main_renderered()
    self:sync_main_cursor()
  end

  ---@class eve.ux.search.search.actions
  local actions = {
    focus_left = function()
      context:focus_left()
    end,
    focus_right = function()
      context:focus_right()
    end,
    focus_input = function()
      context:focus_input()
    end,
    focus_main = function()
      context:focus_main()
    end,
    focus_preview = function()
      context:focus_preview()
    end,
    force_refresh = function()
      context.dirtier_data_cache:mark_dirty()
      context.dirtier_data:mark_dirty()
      context.dirtier_selected:mark_dirty()
    end,
    toggle_current_selected = function()
      local lnum = context:get_current_lnum() ---@type integer
      context:toggle_item_selected(lnum)
    end,
    toggle_visual_selected = function()
      local s_lnum, t_lnum = eve.editor.get_visual_lnum_range() ---@type integer, integer
      local lnums = {} ---@type integer[]
      for lnum = s_lnum, t_lnum, 1 do
        table.insert(lnums, lnum)
      end
      context:toggle_items_selected(lnums)
    end,
    on_main_G = function()
      local lnum = vim.v.count > 0 and vim.v.count or math.huge ---@type integer
      context:locate(lnum)
      self:sync_main_cursor()
    end,
    on_main_g = function()
      local lnum = vim.v.count1 or 1
      context:locate(lnum)
      self:sync_main_cursor()
    end,
    on_main_gg = function()
      context:locate(1)
      self:sync_main_cursor()
    end,
    on_main_down = function()
      context:movedown()
      self:sync_main_cursor()
    end,
    on_main_up = function()
      context:moveup()
      self:sync_main_cursor()
    end,
    on_delete_item = function()
      local uuid = context:get_current_uuid() ---@type string|nil
      if uuid ~= nil then
        context:set_item_deleted(uuid)
      end
    end,
    on_main_mouse_click = function()
      local winnr_main = context.winnr_main ---@type integer|nil
      if winnr_main ~= nil then
        local cursor = vim.fn.getmousepos()
        local winnr = cursor.winid ---@type integer
        if winnr == winnr_main then
          local lnum = cursor.line ---@type integer
          lnum = context:locate(lnum)
          self:sync_main_cursor()
          return
        end
      end

      ---! fallback
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true), "n", false)
    end,
    on_main_mouse_dbclick = function()
      local winnr_main = context.winnr_main ---@type integer|nil
      if winnr_main ~= nil then
        local cursor = vim.fn.getmousepos()
        local winnr = cursor.winid ---@type integer
        if winnr == winnr_main then
          local lnum = cursor.line ---@type integer
          lnum = context:locate(lnum)
          vim.api.nvim_win_set_cursor(winnr_main, { lnum, 0 })
          on_confirm()
          return
        end
      end

      ---! fallback
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<2-LeftMouse>", true, false, true), "n", false)
    end,
  }

  vim.list_extend(common_keymaps, {
    {
      modes = { "i", "n", "v" },
      key = "<LeftMouse>",
      callback = actions.on_main_mouse_click,
      desc = "search: mouse click",
      nowait = true,
    },
    {
      modes = { "i", "n", "v" },
      key = "<2-LeftMouse>",
      callback = actions.on_main_mouse_dbclick,
      desc = "search: confirm",
      nowait = true,
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>r",
      aliases = { "<D-r>", "<M-r>" },
      callback = actions.force_refresh,
      desc = "search: refresh",
    },
  })

  ---@type eve.t.IKeymap[]
  local default_input_keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      callback = actions.focus_main,
      desc = "search: focus down",
    },
    {
      disabled = not enable_preview,
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      callback = actions.focus_right,
      desc = "search: focus right",
    },
    {
      disabled = not context.multiple,
      modes = { "i", "n", "v" },
      key = "<Tab>",
      callback = actions.toggle_current_selected,
      desc = "search: toggle selected",
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>dd",
      callback = actions.on_delete_item,
      desc = "search: delete current item",
    },
  }

  ---@type eve.t.IKeymap[]
  local default_main_keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      callback = actions.focus_input,
      desc = "search: focus up",
    },
    {
      disabled = not enable_preview,
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      callback = actions.focus_right,
      desc = "search: focus right",
    },
    {
      modes = { "i", "n", "v" },
      key = "<Down>",
      aliases = { "<C-j>", "j" },
      callback = actions.on_main_down,
      desc = "search: focus next item",
    },
    {
      modes = { "i", "n", "v" },
      key = "<Up>",
      aliases = { "<C-k>", "k" },
      callback = actions.on_main_up,
      desc = "search: focus prev item",
    },
    {
      disabled = not context.multiple,
      modes = { "i", "n" },
      key = "<Tab>",
      callback = actions.toggle_current_selected,
      desc = "search: toggle selected",
    },
    {
      disabled = not context.multiple,
      modes = { "v" },
      key = "<Tab>",
      callback = actions.toggle_visual_selected,
      desc = "search: toggle selected",
    },
    {
      modes = { "i", "n", "v" },
      key = "<cr>",
      aliases = { "o" },
      callback = on_confirm,
      desc = "search: confirm",
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>dd",
      callback = actions.on_delete_item,
      desc = "search: delete current item",
    },
    {
      modes = { "i", "n", "v" },
      key = "G",
      callback = actions.on_main_G,
      desc = "search: goto last line",
    },
    {
      modes = { "i", "n", "v" },
      key = "g",
      callback = actions.on_main_g,
      desc = "search: locate",
    },
    {
      modes = { "i", "n", "v" },
      key = "gg",
      callback = actions.on_main_gg,
      desc = "search: goto first line",
    },
  }

  ---@type eve.t.IKeymap[]
  local default_preview_keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      callback = actions.focus_left,
      desc = "search: focus left",
    },
    {
      disabled = not context.multiple,
      modes = { "i", "n", "v" },
      key = "<Tab>",
      callback = actions.toggle_current_selected,
      desc = "search: toggle selected",
    },
    {
      modes = { "i", "n", "v" },
      key = "<cr>",
      aliases = { "o" },
      callback = on_confirm,
      desc = "search: confirm",
    },
    {
      modes = { "i", "n", "v" },
      key = "<leader>dd",
      callback = actions.on_delete_item,
      desc = "search: delete current item",
    },
  }

  local input_keymaps = vim.list_slice(common_keymaps) ---@type eve.t.IKeymap[]
  vim.list_extend(input_keymaps, default_input_keymaps)
  vim.list_extend(input_keymaps, props.input_keymaps or {})

  local main_keymaps = vim.list_slice(common_keymaps) ---@type eve.t.IKeymap[]
  vim.list_extend(main_keymaps, default_main_keymaps)
  vim.list_extend(main_keymaps, props.main_keymaps or {})

  local preview_keymaps = vim.list_slice(common_keymaps) ---@type eve.t.IKeymap[]
  vim.list_extend(preview_keymaps, default_preview_keymaps)
  vim.list_extend(preview_keymaps, props.preview_keymaps or {})

  if not context.enable_multiline_input then
    ---@type eve.t.IKeymap[]
    local additional_input_keymaps = {
      { modes = { "i", "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
      { modes = { "i", "n", "v" }, key = "<Down>", callback = actions.on_main_down, desc = "search: focus next item" },
      { modes = { "i", "n", "v" }, key = "<Up>", callback = actions.on_main_up, desc = "search: focus prev item" },
      { modes = { "n", "v" }, key = "j", callback = actions.on_main_down, desc = "search: focus next item" },
      { modes = { "n", "v" }, key = "k", callback = actions.on_main_up, desc = "search: focus prev item" },
      { modes = { "n", "v" }, key = "o", callback = eve.std.fn.noop },
      { modes = { "n", "v" }, key = "O", callback = eve.std.fn.noop },
      { modes = { "n", "v" }, key = "G", callback = actions.on_main_G, desc = "search: goto last line" },
      { modes = { "n", "v" }, key = "g", callback = actions.on_main_g, desc = "search: locate" },
      { modes = { "n", "v" }, key = "gg", callback = actions.on_main_gg, desc = "search: goto first line" },
    }
    vim.list_extend(input_keymaps, additional_input_keymaps)
  else
    ---@param key                       string
    ---@param action                    fun(): nil
    ---@return fun(): nil
    local function create_fallback(key, action)
      return function()
        local line_count = vim.api.nvim_buf_line_count(0) ---@type integer
        if line_count <= 1 then
          action()
        else
          vim.cmd("normal! " .. key)
        end
      end
    end

    local on_input_move_down = create_fallback("j", actions.on_main_down)
    local on_input_move_up = create_fallback("k", actions.on_main_up)
    local on_input_G = create_fallback("G", actions.on_main_G)
    local on_input_g = create_fallback("g", actions.on_main_g)
    local on_input_gg = create_fallback("gg", actions.on_main_gg)

    ---@type eve.t.IKeymap[]
    local additional_input_keymaps = {
      { modes = { "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
      { modes = { "n", "v" }, key = "j", callback = on_input_move_down, desc = "search: focus next item" },
      { modes = { "n", "v" }, key = "k", callback = on_input_move_up, desc = "search: focus prev item" },
      { modes = { "n", "v" }, key = "G", callback = on_input_G, desc = "search: goto last line" },
      { modes = { "n", "v" }, key = "g", callback = on_input_g, desc = "search: locate" },
      { modes = { "n", "v" }, key = "gg", callback = on_input_gg, desc = "search: goto first line" },
    }
    vim.list_extend(input_keymaps, additional_input_keymaps)
  end

  ---@type eve.ux.ISearchInput
  local input = eve.ux.SearchInput.new({
    context = context,
    keymaps = input_keymaps,
  })

  ---@type eve.ux.ISearchMain
  local main = eve.ux.SearchMain.new({
    context = context,
    keymaps = main_keymaps,
    on_rendered = on_main_renderered,
    delay_render = delay_render,
  })

  ---@type eve.ux.ISearchPreview|nil
  local preview = nil
  if enable_preview and props.fetch_preview_data then
    preview = eve.ux.SearchPreview.new({
      context = context,
      keymaps = preview_keymaps,
      fetch_data = props.fetch_preview_data,
      patch_data = props.patch_preview_data,
      on_rendered = props.on_preview_rendered,
      delay_render = delay_render,
      update_win_config = function(opts)
        local new_title = opts.title ---@type string
        self:change_preview_title(new_title)

        local winnr = context.winnr_preview ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          local lnum = opts.lnum ---@type integer|nil
          local col = opts.col ---@type integer|nil
          if lnum ~= nil and col ~= nil then
            vim.api.nvim_win_set_cursor(winnr, { lnum, col })
          end
        end
      end,
    })
  end

  self.context = context
  self.statusline_items = statusline_items
  self._input = input
  self._main = main
  self._preview = preview
  self._on_close = on_close_from_props
  self._on_invisible = on_invisible_from_props

  local draw_wins_scheduler = eve.std.Scheduler.new({
    name = "eve.ux.search.search.draw",
    delay = 64,
    task = function(callback)
      local status = context.status:snapshot() ---@type eve.e.WidgetStatus
      local visible = status == "visible" ---@type boolean
      if visible then
        self:create_wins_as_needed()
        self.context.dirtier_dimension:mark_clean()
      end
      callback("fulfilled")
    end,
  })

  ---@return nil
  local function trigger_draw_wins()
    local status = context.status:snapshot() ---@type eve.e.WidgetStatus
    local visible = status == "visible" ---@type boolean
    if visible then
      draw_wins_scheduler:schedule()
    end
  end

  context.status:subscribe(
    eve.std.Subscriber.new({
      on_next = function()
        trigger_draw_wins()
      end,
    }),
    true
  )

  context.state_has_matched:subscribe(
    eve.std.Subscriber.new({
      on_next = function(flag)
        local winnr_main = context.winnr_main ---@type integer|nil
        if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
          vim.wo[winnr_main].cursorline = flag
        end

        local winnr_preview = context.winnr_preview ---@type integer|nil
        if winnr_preview ~= nil and vim.api.nvim_win_is_valid(winnr_preview) then
          vim.wo[winnr_preview].cursorline = flag
        end
      end,
    }),
    true
  )

  context.dirtier_dimension:subscribe(
    eve.std.Subscriber.new({
      on_next = function()
        local is_dimension_dirty = context.dirtier_dimension:is_dirty() ---@type boolean
        if is_dimension_dirty then
          trigger_draw_wins()
        end
      end,
    }),
    true
  )

  context.dirtier_main:subscribe(
    eve.std.Subscriber.new({
      on_next = function()
        local is_main_dirty = context.dirtier_main:is_dirty() ---@type boolean
        if is_main_dirty then
          trigger_draw_wins()
        end
      end,
    }),
    true
  )

  ---! Trigger the preview dirty change when the preview not exist.
  if preview == nil then
    context.dirtier_preview:subscribe(
      eve.std.Subscriber.new({
        on_next = function()
          local is_preview_dirty = context.dirtier_preview:is_dirty() ---@type boolean
          if is_preview_dirty then
            trigger_draw_wins()
          end
        end,
      }),
      true
    )
  end

  context.dirtier_selected:subscribe(
    eve.std.Subscriber.new({
      on_next = function()
        local is_selected_dirty = context.dirtier_selected:is_dirty() ---@type boolean
        if is_selected_dirty then
          context:place_selected_sign()
          context:place_lnum_sign()
        end
      end,
    }),
    true
  )

  if context.enable_multiline_input then
    context.input_line_count:subscribe(
      eve.std.Subscriber.new({
        on_next = function()
          trigger_draw_wins()
        end,
      }),
      true
    )
  end

  return self
end

---@return nil
function M:sync_main_cursor()
  local context = self.context ---@type eve.ux.ISearchContext
  local winnr_main = context.winnr_main ---@type integer|nil
  if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
    local lnum = context:place_lnum_sign() ---@type integer|nil
    if lnum ~= nil then
      vim.api.nvim_win_set_cursor(winnr_main, { lnum, 0 })
    end
  end
end

---@return nil
function M:create_wins_as_needed()
  local context = self.context ---@type eve.ux.ISearchContext
  local dimension = context.dimension ---@type eve.ux.ISearchDimension

  local bufnr_input = self._input:create_buf_as_needed() ---@type integer
  local bufnr_main = self._main:create_buf_as_needed() ---@type integer
  local screen_height = vim.o.lines ---@type integer
  local screen_width = vim.o.columns ---@type integer
  local winblend = eve.state.theme.transparency:snapshot() and 0 or 10 ---@type integer

  local match_count = #context.items ---@type integer
  local has_preview = vim.o.columns > 140 and self._preview ~= nil ---@type boolean
  local has_main = match_count > 0 or has_preview ---@type boolean

  ---@type number
  local max_height = dimension.max_height <= 1 and math.floor(dimension.max_height * screen_height)
    or dimension.max_height
  ---@type number
  local max_width = dimension.max_width <= 1 and math.floor(dimension.max_width * screen_width) or dimension.max_width

  local input_height = context.enable_multiline_input and math.max(1, math.min(3, context.input_line_count:snapshot()))
    or 1
  local input_height_with_borders = input_height + 1 ---@type integer

  local height = dimension.height or (#context.items_original + input_height_with_borders) ---@type number
  if height < 1 then
    height = math.floor(height * screen_height)
  end
  height = math.min(max_height, math.max(input_height_with_borders, height)) ---@type integer

  local width = dimension.width or context.item_max_width + 10 ---@type number
  if width < 1 then
    width = math.floor(width * screen_width)
  end
  width = math.min(max_width, math.max(10, width)) ---@type integer

  local prefer_row = dimension.row or screen_height ---@type number
  if prefer_row < 1 then
    prefer_row = math.floor(prefer_row * screen_height)
  end
  prefer_row = math.min(screen_height, math.max(0, prefer_row)) ---@type integer

  local prefer_col = dimension.col or screen_width ---@type number
  if prefer_col < 1 then
    prefer_col = math.floor(prefer_col * screen_width)
  end
  prefer_col = math.min(screen_width, math.max(0, prefer_col)) ---@type integer

  local width_preview = dimension.width_preview or width ---@type integer
  if width_preview < 1 then
    width_preview = math.floor(width_preview * screen_width)
  end
  width_preview = math.min(max_width - width - 2, math.max(10, width_preview))

  if not has_preview then
    width = width + width_preview
    width_preview = 0
  end

  local row = math.min(prefer_row, math.floor((screen_height - height) / 2) - 1) ---@type integer
  local col = math.min(prefer_col, math.floor((screen_width - width - width_preview - 2) / 2)) ---@type integer
  local winnr_input = context.winnr_input ---@type integer|nil
  local winnr_main = context.winnr_main ---@type integer|nil
  local winnr_preview = context.winnr_preview ---@type integer|nil

  local winnr_main_new_created = false ---@type boolean

  if has_main then
    ---@type vim.api.keyset.win_config
    local wincfg_main = {
      relative = "editor",
      anchor = "NW",
      height = has_preview and height - input_height_with_borders
        or math.min(match_count + 1, height - input_height_with_borders),
      width = width,
      row = row + input_height_with_borders,
      col = col,
      focusable = true,
      title = "",
      border = has_preview and borders.main_with_preview or borders.main,
      style = "minimal",
    }

    if winnr_main == nil or not vim.api.nvim_win_is_valid(winnr_main) then
      winnr_main = vim.api.nvim_open_win(bufnr_main, true, wincfg_main)
      context.winnr_main = winnr_main
      winnr_main_new_created = true

      vim.wo[winnr_main].number = false
      vim.wo[winnr_main].relativenumber = false
      vim.wo[winnr_main].signcolumn = "yes"
      vim.wo[winnr_main].wrap = false
    else
      vim.wo[winnr_main].winfixbuf = false
      vim.api.nvim_win_set_config(winnr_main, wincfg_main)
      vim.api.nvim_win_set_buf(winnr_main, bufnr_main)
    end

    vim.wo[winnr_main].cursorline = match_count > 0
    vim.wo[winnr_main].winblend = winblend
    vim.wo[winnr_main].winhighlight = highlights.main
    vim.wo[winnr_main].winfixbuf = true
    self:sync_main_cursor()
  else
    context.winnr_main = nil
    if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
      vim.api.nvim_win_close(winnr_main, true)
    end
  end

  if not has_preview and winnr_preview ~= nil and vim.api.nvim_win_is_valid(winnr_preview) then
    vim.api.nvim_win_close(winnr_preview, true)
    winnr_preview = nil
    context.winnr_preview = nil
  elseif has_preview and self._preview then
    ---@type vim.api.keyset.win_config
    local wincfg_preview = {
      relative = "editor",
      anchor = "NW",
      height = height,
      width = width_preview,
      row = row,
      col = col + width + 1,
      focusable = true,
      title = " " .. context.cfg_preview_title .. " ",
      title_pos = "center",
      border = borders.preview,
      style = "minimal",
    }

    local bufnr_preview = self._preview:create_buf_as_needed() ---@type integer
    if winnr_preview == nil or not vim.api.nvim_win_is_valid(winnr_preview) then
      winnr_preview = vim.api.nvim_open_win(bufnr_preview, true, wincfg_preview)
      context.winnr_preview = winnr_preview

      ---@type integer|nil, integer|nil
      local preview_lnum, preview_col = self._preview:get_current_location()
      if preview_lnum ~= nil and preview_col ~= nil then
        vim.api.nvim_win_set_cursor(winnr_preview, { preview_lnum, preview_col })
      end

      vim.wo[winnr_preview].number = true
      vim.wo[winnr_preview].relativenumber = false
      vim.wo[winnr_preview].signcolumn = "yes"
      vim.wo[winnr_preview].list = true
      vim.wo[winnr_preview].listchars = string.format(
        "eol:%s,lead:%s,nbsp:%s,space:%s,trail:%s",
        eve.icon.listchars.eol,
        eve.icon.listchars.lead,
        eve.icon.listchars.nbsp,
        eve.icon.listchars.space,
        eve.icon.listchars.trail
      )
    else
      vim.wo[winnr_preview].winfixbuf = false
      vim.api.nvim_win_set_config(winnr_preview, wincfg_preview)
      vim.api.nvim_win_set_buf(winnr_preview, bufnr_preview)
    end

    vim.wo[winnr_preview].number = true
    vim.wo[winnr_preview].cursorline = match_count > 0
    vim.wo[winnr_preview].winblend = winblend
    vim.wo[winnr_preview].winhighlight = highlights.preview
    vim.wo[winnr_preview].winfixbuf = true
    vim.wo[winnr_preview].wrap = context.cfg_preview_wrap
  end

  ---@type vim.api.keyset.win_config
  local wincfg_input = {
    relative = "editor",
    anchor = "NW",
    height = input_height,
    width = width,
    row = row,
    col = col,
    focusable = true,
    title = " " .. context.cfg_input_title .. " ",
    title_pos = "center",
    border = has_main and (has_preview and borders.input_with_preview or borders.input) or borders.input_without_main,
    style = "minimal",
  }
  if winnr_input == nil or not vim.api.nvim_win_is_valid(winnr_input) then
    winnr_input = vim.api.nvim_open_win(bufnr_input, true, wincfg_input)
    context.winnr_input = winnr_input

    vim.wo[winnr_input].number = false
    vim.wo[winnr_input].relativenumber = false
    vim.wo[winnr_input].signcolumn = "yes:1"
    vim.wo[winnr_input].wrap = false
  else
    vim.wo[winnr_input].winfixbuf = false
    vim.api.nvim_win_set_config(winnr_input, wincfg_input)
    vim.api.nvim_win_set_buf(winnr_input, bufnr_input)
  end

  vim.wo[winnr_input].winblend = winblend
  vim.wo[winnr_input].winhighlight = highlights.input
  vim.wo[winnr_input].winfixbuf = true

  vim.schedule(function()
    local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
    if context.focused_pane == "input" then
      if winnr_input ~= nil and winnr_cur ~= winnr_input then
        vim.api.nvim_tabpage_set_win(0, winnr_input)
      end
    elseif context.focused_pane == "main" then
      if winnr_main_new_created then
        if winnr_input ~= nil and winnr_cur ~= winnr_input then
          vim.api.nvim_tabpage_set_win(0, winnr_input)
        end
      else
        if winnr_main ~= nil and winnr_cur ~= winnr_main then
          vim.api.nvim_tabpage_set_win(0, winnr_main)
        end
      end
    elseif context.focused_pane == "preview" then
      if winnr_preview ~= nil and winnr_cur ~= winnr_preview then
        vim.api.nvim_tabpage_set_win(0, winnr_preview)
      end
    end
  end)
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  local context = self.context ---@type eve.ux.ISearchContext
  context.cfg_input_title = title
  local winnr = context.winnr_input ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    ---@type vim.api.keyset.win_config
    local win_conf_cur = vim.api.nvim_win_get_config(winnr)
    win_conf_cur.title = " " .. title .. " "
    vim.api.nvim_win_set_config(winnr, win_conf_cur)
  end
end

---@param title                         string
---@return nil
function M:change_preview_title(title)
  local context = self.context ---@type eve.ux.ISearchContext
  context.cfg_preview_title = title
  local winnr = context.winnr_preview ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    ---@type vim.api.keyset.win_config
    local win_conf_cur = vim.api.nvim_win_get_config(winnr)
    win_conf_cur.title = " " .. title .. " "
    vim.api.nvim_win_set_config(winnr, win_conf_cur)
  end
end

---@return nil
function M:close()
  local context = self.context ---@type eve.ux.ISearchContext

  self:hide()

  if not context.permanent then
    self.context.status:next("closed")
    self._input:destroy()
    self._main:destroy()

    if self._preview ~= nil then
      self._preview:destroy()
    end

    if self._on_close ~= nil then
      self._on_close()
    end
  end
end

---@return nil
function M:focus()
  local status = self.context.status:snapshot() ---@type eve.e.WidgetStatus
  if status == "closed" then
    self.context.dirtier_data_cache:mark_dirty()
    self.context.dirtier_data:mark_dirty()
  end

  if not self:focused() then
    self._input:create_buf_as_needed()
    self._main:render()
    if self._preview ~= nil then
      self._preview:render()
    end
    self._input:reset_input()
    self.context.status:next("visible")
  end
end

---@return boolean
function M:focused()
  local context = self.context ---@type eve.ux.ISearchContext
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  return winnr_cur == context.winnr_input or winnr_cur == context.winnr_main or winnr_cur == context.winnr_preview
end

---@return eve.ux.search.IItem|nil
---@return integer
function M:get_item_selected()
  return self.context:get_current()
end

---@return integer|nil
function M:get_winnr_main()
  return self.context.winnr_main
end

---@return integer|nil
function M:get_winnr_input()
  return self.context.winnr_input
end

---@return integer|nil
function M:get_winnr_preview()
  return self.context.winnr_preview
end

---@return nil
function M:hide()
  local context = self.context ---@type eve.ux.ISearchContext
  local winnr_input = context.winnr_input ---@type integer|nil
  local winnr_main = context.winnr_main ---@type integer|nil
  local winnr_preview = context.winnr_preview ---@type integer|nil

  context.winnr_input = nil
  context.winnr_main = nil
  context.winnr_preview = nil
  context.status:next("hidden")

  if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
    vim.api.nvim_win_close(winnr_input, true)
  end

  if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
    vim.api.nvim_win_close(winnr_main, true)
  end

  if winnr_preview ~= nil and vim.api.nvim_win_is_valid(winnr_preview) then
    vim.api.nvim_win_close(winnr_preview, true)
  end

  if self._on_invisible ~= nil then
    self._on_invisible()
  end
end

---@param uuid                          string
---@return nil
function M:mark_item_deleted(uuid)
  self.context:set_item_deleted(uuid)
end

---@param text                          string
---@return nil
function M:reset_input(text)
  self._input:reset_input(text)
end

---@return nil
function M:resize()
  self.context.dirtier_dimension:mark_dirty()
end

---@return nil
function M:show()
  eve.state.widget.open(self)
end

---@return eve.e.WidgetStatus
function M:status()
  local status = self.context.status:snapshot() ---@type eve.e.WidgetStatus
  return status
end

---@return nil
function M:toggle()
  if self:focused() then
    self:hide()
  else
    self:show()
  end
end

return M
