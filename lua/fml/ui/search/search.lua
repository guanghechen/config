local api_state = require("fml.api.state")
local util = require("fml.util")
local SearchInput = require("fml.ui.search.input")
local SearchMain = require("fml.ui.search.main")
local SearchPreview = require("fml.ui.search.preview")
local SearchState = require("fml.ui.search.state")

---@type string
local INPUT_WIN_HIGHLIGHT = table.concat({
  "FloatBorder:f_us_input_border",
  "FloatTitle:f_us_input_title",
  "Normal:f_us_input_normal",
}, ",")

---@type string
local MAIN_WIN_HIGHLIGHT = table.concat({
  "Cursor:f_us_main_current",
  "CursorColumn:f_us_main_current",
  "CursorLine:f_us_main_current",
  "CursorLineNr:f_us_main_current",
  "FloatBorder:f_us_main_border",
  "Normal:f_us_main_normal",
}, ",")

local PREVIEW_WIN_HIGHLIGHT = table.concat({
  "Cursor:f_us_preview_current",
  "CursorColumn:f_us_preview_current",
  "CursorLine:f_us_preview_current",
  "CursorLineNr:f_us_preview_current",
  "FloatBorder:f_us_preview_border",
  "FloatTitle:f_us_preview_title",
  "Normal:f_us_preview_normal",
}, ",")

---@class fml.ui.search.Search : fml.types.ui.search.ISearch
---@field protected _alive              boolean
---@field protected _destroy_on_close   boolean
---@field protected _dimension          fml.types.ui.search.IDimension
---@field protected _input              fml.types.ui.search.IInput
---@field protected _main               fml.types.ui.search.IMain
---@field protected _preview            fml.types.ui.search.IPreview|nil
---@field protected _preview_title      string
---@field protected _winnr_input        integer|nil
---@field protected _winnr_main         integer|nil
---@field protected _winnr_preview      integer|nil
---@field protected _on_close           ?fml.types.ui.search.IOnClose
local M = {}
M.__index = M

---@class fml.types.ui.search.IProps
---@field public destroy_on_close       ?boolean
---@field public dimension              ?fml.types.ui.search.IRawDimension
---@field public enable_multiline_input ?boolean
---@field public fetch_data             fml.types.ui.search.IFetchData
---@field public delay_fetch            ?integer
---@field public fetch_preview_data     ?fml.types.ui.search.IFetchPreviewData
---@field public input                  eve.types.collection.IObservable
---@field public input_history          eve.types.collection.IHistory|nil
---@field public input_keymaps          ?fml.types.IKeymap[]
---@field public main_keymaps           ?fml.types.IKeymap[]
---@field public patch_preview_data     ?fml.types.ui.search.IPatchPreviewData
---@field public preview_keymaps        ?fml.types.IKeymap[]
---@field public delay_render           ?integer
---@field public statusline_items       eve.types.ux.widgets.IRawStatuslineItem[]
---@field public title                  string
---@field public on_close               ?fml.types.ui.search.IOnClose
---@field public on_confirm             fml.types.ui.search.IOnConfirm
---@field public on_preview_rendered    ?fml.types.ui.search.IOnPreviewRendered

---@param props                         fml.types.ui.search.IProps
---@return fml.ui.search.Search
function M.new(props)
  local self = setmetatable({}, M)

  local common_keymaps = {} ---@type fml.types.IKeymap[]
  local statusline_items = {} ---@type eve.types.ux.widgets.IStatuslineItem[]

  local raw_statusline_items = props.statusline_items ---@type eve.types.ux.widgets.IRawStatuslineItem[]
  for idx, item in ipairs(raw_statusline_items) do
    local state = item.state ---@type eve.types.collection.IObservable
    local symbol = item.symbol ---@type string
    local callback = item.callback ---@type fun(): nil
    local callback_fn = eve.G.register_anonymous_fn(callback) or "" ---@type string

    ---@type eve.types.ux.widgets.IStatuslineItem
    local statusline_item = { type = item.type, state = state, symbol = symbol, callback_fn = callback_fn }
    table.insert(statusline_items, statusline_item)

    ---@type fml.types.IKeymap
    local keymap = {
      modes = { "n", "v" },
      key = "<leader>" .. idx,
      callback = callback,
      desc = item.desc,
      nowait = true,
    }
    table.insert(common_keymaps, keymap)
  end

  local raw_dimension = props.dimension or {} ---@type fml.types.ui.search.IRawDimension
  ---@type fml.types.ui.search.IDimension
  local dimension = {
    height = raw_dimension.height,
    max_width = raw_dimension.max_width or 0.8,
    max_height = raw_dimension.max_height or 0.8,
    width = raw_dimension.width,
    width_preview = raw_dimension.width_preview,
  }

  local delay_fetch = math.max(0, props.delay_fetch or 128) ---@type integer
  local delay_render = math.max(0, props.delay_render or 48) ---@type integer
  local destroy_on_close = not not props.destroy_on_close ---@type boolean
  local enable_multiline_input = not not props.enable_multiline_input ---@type boolean
  local input_history = props.input_history ---@type eve.types.collection.IHistory|nil

  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.search.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.types.ui.search.IOnClose|nil

  ---@type fml.types.ui.search.IState
  local state = SearchState.new({
    title = props.title,
    input = props.input,
    input_history = input_history,
    fetch_data = props.fetch_data,
    delay_fetch = delay_fetch,
    enable_multiline_input = enable_multiline_input,
  })

  ---@return nil
  local function on_close()
    self:close()
  end

  ---@return nil
  local function on_confirm()
    local item = state:get_current() ---@type fml.types.ui.search.IItem|nil
    if item ~= nil then
      if on_confirm_from_props(item) then
        if input_history ~= nil then
          local top = input_history:top() ---@type string|nil
          if top ~= nil then
            top = util.unwrap_editing_prefix(top)
            input_history:update_top(top)
          end
        end
        on_close()
      end
    end
  end

  ---@return nil
  local function on_main_renderered()
    self:sync_main_cursor()
  end

  ---@class fml.ui.search.search.actions
  local actions = {
    noop = eve.util.noop,
    close = function()
      on_close()
    end,
    focus_preview = function()
      local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
      local winnr_preview = self:get_winnr_preview() ---@type integer|nil
      if winnr_preview ~= nil and winnr ~= winnr_preview and vim.api.nvim_win_is_valid(winnr_preview) then
        vim.api.nvim_tabpage_set_win(0, winnr_preview)
      end
    end,
    focus_input = function()
      local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
      local winnr_input = self:get_winnr_input() ---@type integer|nil
      if winnr_input ~= nil and winnr ~= winnr_input and vim.api.nvim_win_is_valid(winnr_input) then
        vim.api.nvim_tabpage_set_win(0, winnr_input)
      end
    end,
    force_refresh = function()
      state.force_on_fetch_data:next(true)
      state.dirtier_data:mark_dirty()
    end,
    on_main_G = function()
      local lnum = vim.v.count > 0 and vim.v.count or math.huge ---@type integer
      state:locate(lnum)
      self:sync_main_cursor()
    end,
    on_main_g = function()
      local lnum = vim.v.count1 or 1
      state:locate(lnum)
      self:sync_main_cursor()
    end,
    on_main_gg = function()
      state:locate(1)
      self:sync_main_cursor()
    end,
    on_main_down = function()
      state:movedown()
      self:sync_main_cursor()
    end,
    on_main_up = function()
      state:moveup()
      self:sync_main_cursor()
    end,
    on_delete_item = function()
      local uuid = state:get_current_uuid() ---@type string|nil
      if uuid ~= nil then
        state:mark_item_deleted(uuid)
      end
    end,
    on_main_mouse_click = function()
      ---@diagnostic disable-next-line: invisible
      local winnr_main = self._winnr_main ---@type integer|nil
      if winnr_main ~= nil then
        local cursor = vim.fn.getmousepos()
        local winnr = cursor.winid ---@type integer
        if winnr == winnr_main then
          local lnum = cursor.line ---@type integer
          lnum = state:locate(lnum)
          self:sync_main_cursor()
          return
        end
      end

      ---! fallback
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<LeftMouse>", true, false, true), "n", false)
    end,
    on_main_mouse_dbclick = function()
      ---@diagnostic disable-next-line: invisible
      local winnr_main = self._winnr_main ---@type integer|nil
      if winnr_main ~= nil then
        local cursor = vim.fn.getmousepos()
        local winnr = cursor.winid ---@type integer
        if winnr == winnr_main then
          local lnum = cursor.line ---@type integer
          lnum = state:locate(lnum)
          vim.api.nvim_win_set_cursor(winnr_main, { lnum, 0 })
          on_confirm()
          return
        end
      end

      ---! fallback
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<2-LeftMouse>", true, false, true), "n", false)
    end,
  }

  eve.array.extend(common_keymaps, {
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
    { modes = { "i", "n", "v" }, key = "<M-r>", callback = actions.force_refresh, desc = "search: refresh" },
    { modes = { "i", "n", "v" }, key = "<C-a>r", callback = actions.force_refresh, desc = "search: refresh" },
    { modes = { "n", "v" }, key = "q", callback = actions.close, desc = "search: close" },
  })

  ---@type fml.types.IKeymap[]
  local left_common_keymaps = {
    { modes = { "i", "n", "v" }, key = "<M-j>", callback = actions.on_main_down, desc = "search: focus next item" },
    { modes = { "i", "n", "v" }, key = "<C-a>j", callback = actions.on_main_down, desc = "search: focus next item" },
    { modes = { "i", "n", "v" }, key = "<M-k>", callback = actions.on_main_up, desc = "search: focus prev item" },
    { modes = { "i", "n", "v" }, key = "<C-a>k", callback = actions.on_main_up, desc = "search: focus prev item" },
    { modes = { "i", "n", "v" }, key = "<M-l>", callback = actions.focus_preview, desc = "search: focus preview" },
    { modes = { "i", "n", "v" }, key = "<C-a>l", callback = actions.focus_preview, desc = "search: focus preview" },
    {
      modes = { "i", "n", "v" },
      key = "<leader>dd",
      callback = actions.on_delete_item,
      desc = "search: delete current item",
    },
  }

  ---@type fml.types.IKeymap[]
  local input_keymaps = eve.array.concat(common_keymaps, left_common_keymaps, props.input_keymaps or {})

  ---@type fml.types.IKeymap[]
  local main_keymaps = eve.array.concat(common_keymaps, left_common_keymaps, {
    { modes = { "i", "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
    { modes = { "n", "v" }, key = "j", callback = actions.on_main_down, desc = "search: focus next item" },
    { modes = { "n", "v" }, key = "k", callback = actions.on_main_up, desc = "search: focus prev item" },
    { modes = { "n", "v" }, key = "G", callback = actions.on_main_G, desc = "search: goto last line" },
    { modes = { "n", "v" }, key = "g", callback = actions.on_main_g, desc = "search: locate" },
    { modes = { "n", "v" }, key = "gg", callback = actions.on_main_gg, desc = "search: goto first line" },
  }, props.main_keymaps or {})

  ---@type fml.types.IKeymap[]
  local preview_keymaps = eve.array.concat(common_keymaps, {
    { modes = { "i", "n", "v" }, key = "<M-h>", callback = actions.focus_input, desc = "search: focus input" },
    { modes = { "i", "n", "v" }, key = "<C-a>h", callback = actions.focus_input, desc = "search: focus input" },
    { modes = { "i", "n", "v" }, key = "<M-j>", callback = actions.on_main_down, desc = "search: focus next item" },
    { modes = { "i", "n", "v" }, key = "<C-a>j", callback = actions.on_main_down, desc = "search: focus next item" },
    { modes = { "i", "n", "v" }, key = "<M-k>", callback = actions.on_main_up, desc = "search: focus prev item" },
    { modes = { "i", "n", "v" }, key = "<C-a>k", callback = actions.on_main_up, desc = "search: focus prev item" },
    { modes = { "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
    { modes = { "n", "v" }, key = "q", callback = actions.close, desc = "search: close" },
  }, props.preview_keymaps or {})

  if not enable_multiline_input then
    ---@type fml.types.IKeymap[]
    local additional_input_keymaps = {
      { modes = { "i", "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
      { modes = { "n", "v" }, key = "j", callback = actions.on_main_down, desc = "search: focus next item" },
      { modes = { "n", "v" }, key = "k", callback = actions.on_main_up, desc = "search: focus prev item" },
      { modes = { "n", "v" }, key = "o", callback = actions.noop },
      { modes = { "n", "v" }, key = "O", callback = actions.noop },
      { modes = { "n", "v" }, key = "G", callback = actions.on_main_G, desc = "search: goto last line" },
      { modes = { "n", "v" }, key = "g", callback = actions.on_main_g, desc = "search: locate" },
      { modes = { "n", "v" }, key = "gg", callback = actions.on_main_gg, desc = "search: goto first line" },
    }
    eve.array.extend(input_keymaps, additional_input_keymaps)
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

    ---@type fml.types.IKeymap[]
    local additional_input_keymaps = {
      { modes = { "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
      { modes = { "n", "v" }, key = "j", callback = on_input_move_down, desc = "search: focus next item" },
      { modes = { "n", "v" }, key = "k", callback = on_input_move_up, desc = "search: focus prev item" },
      { modes = { "n", "v" }, key = "G", callback = on_input_G, desc = "search: goto last line" },
      { modes = { "n", "v" }, key = "g", callback = on_input_g, desc = "search: locate" },
      { modes = { "n", "v" }, key = "gg", callback = on_input_gg, desc = "search: goto first line" },
    }
    eve.array.extend(input_keymaps, additional_input_keymaps)
  end

  ---@type fml.types.ui.search.IInput
  local input = SearchInput.new({
    state = state,
    keymaps = input_keymaps,
  })

  ---@type fml.types.ui.search.IMain
  local main = SearchMain.new({
    state = state,
    keymaps = main_keymaps,
    on_rendered = on_main_renderered,
    delay_render = delay_render,
  })

  ---@type fml.types.ui.search.IPreview|nil
  local preview = nil
  if props.fetch_preview_data then
    preview = SearchPreview.new({
      state = state,
      keymaps = preview_keymaps,
      fetch_data = props.fetch_preview_data,
      patch_data = props.patch_preview_data,
      on_rendered = props.on_preview_rendered,
      delay_render = delay_render,
      update_win_config = function(opts)
        local new_title = opts.title ---@type string
        self:change_preview_title(new_title)

        local winnr = self:get_winnr_preview() ---@type integer|nil
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

  self.state = state
  self.statusline_items = statusline_items
  self._alive = true
  self._destroy_on_close = destroy_on_close
  self._dimension = dimension
  self._input = input
  self._main = main
  self._preview = preview
  self._preview_title = " preview "
  self._winnr_input = nil
  self._winnr_main = nil
  self._winnr_preview = nil
  self._on_close = on_close_from_props

  ---@type eve.std.scheduler.IScheduler
  local draw_scheduler = eve.scheduler.throttle({
    name = "fml.ui.search.search.draw",
    delay = 48,
    fn = function(callback)
      local visible = state.visible:snapshot() ---@type boolean
      if visible then
        self:create_wins_as_needed()
        self.state.dirtier_dimension:mark_clean()
      end
      callback(true)
    end,
  })

  state.visible:subscribe(
    eve.c.Subscriber.new({
      on_next = function()
        local visible = state.visible:snapshot() ---@type boolean
        if visible then
          draw_scheduler:schedule()
        end
      end,
    }),
    true
  )

  state.dirtier_dimension:subscribe(
    eve.c.Subscriber.new({
      on_next = function()
        local is_dimension_dirty = state.dirtier_dimension:is_dirty() ---@type boolean
        local visible = state.visible:snapshot() ---@type boolean
        if visible and is_dimension_dirty then
          draw_scheduler:schedule()
        end
      end,
    }),
    true
  )

  state.dirtier_main:subscribe(
    eve.c.Subscriber.new({
      on_next = function()
        local is_main_dirty = state.dirtier_main:is_dirty() ---@type boolean
        local visible = state.visible:snapshot() ---@type boolean
        if visible and is_main_dirty then
          draw_scheduler:schedule()
        end
      end,
    }),
    true
  )

  ---! Trigger the preview dirty change when the preview not exist.
  if preview == nil then
    state.dirtier_preview:subscribe(
      eve.c.Subscriber.new({
        on_next = function()
          local is_preview_dirty = state.dirtier_preview:is_dirty() ---@type boolean
          local visible = state.visible:snapshot() ---@type boolean
          if visible and is_preview_dirty then
            draw_scheduler:schedule()
          end
        end,
      }),
      true
    )
  end

  if enable_multiline_input then
    state.input_line_count:subscribe(
      eve.c.Subscriber.new({
        on_next = function()
          local visible = state.visible:snapshot() ---@type boolean
          if visible then
            draw_scheduler:schedule()
          end
        end,
      }),
      true
    )
  end

  return self
end

---@return nil
function M:sync_main_cursor()
  local winnr_main = self._winnr_main ---@type integer|nil
  if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
    local lnum = self._main:place_lnum_sign() ---@type integer|nil
    if lnum ~= nil then
      vim.api.nvim_win_set_cursor(winnr_main, { lnum, 0 })
    end
  end
end

---@return boolean
function M:alive()
  return self._alive
end

---@return nil
function M:create_wins_as_needed()
  local state = self.state ---@type fml.types.ui.search.IState
  local bufnr_input = self._input:create_buf_as_needed() ---@type integer
  local bufnr_main = self._main:create_buf_as_needed() ---@type integer
  local dimension = self._dimension ---@type fml.types.ui.search.IDimension
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer

  ---@type number
  local max_height = dimension.max_height <= 1 and math.floor(vim.o.lines * dimension.max_height)
    or dimension.max_height
  ---@type number
  local max_width = dimension.max_width <= 1 and math.floor(vim.o.columns * dimension.max_width) or dimension.max_width

  local input_height = state.enable_multiline_input and math.max(1, math.min(3, state.input_line_count:snapshot())) or 1
  local input_height_with_borders = input_height + 2 ---@type integer

  local height = dimension.height or (#state.items + input_height_with_borders) ---@type number
  if height < 1 then
    height = math.floor(vim.o.lines * height)
  end
  height = math.min(max_height, math.max(input_height_with_borders, height)) ---@type integer

  local width = dimension.width or state.max_width + 10 ---@type number
  if width < 1 then
    width = math.floor(vim.o.columns * width)
  end
  width = math.min(max_width, math.max(10, width)) ---@type integer

  local has_preview = self._preview ~= nil ---@type boolean

  local width_preview = dimension.width_preview or width ---@type integer
  if width_preview < 1 then
    width_preview = math.floor(vim.o.columns * width_preview)
  end
  width_preview = has_preview and math.min(max_width - width - 2, math.max(10, width_preview)) or 0

  local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
  local col = math.floor((vim.o.columns - width - width_preview - 2) / 2) ---@type integer
  local winnr_input = self._winnr_input ---@type integer|nil
  local winnr_main = self._winnr_main ---@type integer|nil
  local winnr_preview = self._winnr_preview ---@type integer|nil

  local match_count = #state.items ---@type integer
  if match_count > 0 or self._preview ~= nil then
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
      border = { " ", " ", " ", " ", " ", " ", " ", " " }, --- "rounded", --- { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
      style = "minimal",
    }
    if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
      vim.api.nvim_win_set_config(winnr_main, wincfg_main)
      vim.api.nvim_win_set_buf(winnr_main, bufnr_main)
    else
      winnr_main = vim.api.nvim_open_win(bufnr_main, true, wincfg_main)
      self._winnr_main = winnr_main
    end

    vim.wo[winnr_main].cursorline = match_count > 0
    vim.wo[winnr_main].number = false
    vim.wo[winnr_main].relativenumber = false
    vim.wo[winnr_main].signcolumn = "yes"
    vim.wo[winnr_main].winblend = 10
    vim.wo[winnr_main].winhighlight = MAIN_WIN_HIGHLIGHT
    vim.wo[winnr_main].wrap = false
    self:sync_main_cursor()
  else
    self._winnr_main = nil
    if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
      vim.api.nvim_win_close(winnr_main, true)
    end
  end

  if self._preview then
    ---@type vim.api.keyset.win_config
    local wincfg_preview = {
      relative = "editor",
      anchor = "NW",
      height = height,
      width = width_preview,
      row = row,
      col = col + width + 2,
      focusable = true,
      title = " " .. self._preview_title .. " ",
      title_pos = "center",
      border = { " ", " ", " ", " ", " ", " ", " ", " " }, --- "rounded", --- { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
      style = "minimal",
    }

    local bufnr_preview = self._preview:create_buf_as_needed() ---@type integer
    if winnr_preview ~= nil and vim.api.nvim_win_is_valid(winnr_preview) then
      vim.api.nvim_win_set_config(winnr_preview, wincfg_preview)
      vim.api.nvim_win_set_buf(winnr_preview, bufnr_preview)
    else
      winnr_preview = vim.api.nvim_open_win(bufnr_preview, true, wincfg_preview)
      self._winnr_preview = winnr_preview
    end

    vim.wo[winnr_preview].cursorline = match_count > 0
    vim.wo[winnr_preview].number = true
    vim.wo[winnr_preview].relativenumber = false
    vim.wo[winnr_preview].signcolumn = "yes:1"
    vim.wo[winnr_preview].winblend = 10
    vim.wo[winnr_preview].winhighlight = PREVIEW_WIN_HIGHLIGHT
    vim.wo[winnr_preview].wrap = false
    vim.wo[winnr_preview].list = true
    vim.wo[winnr_preview].listchars = string.format(
      "eol:%s,lead:%s,nbsp:%s,space:%s,trail:%s",
      eve.icons.listchars.eol,
      eve.icons.listchars.lead,
      eve.icons.listchars.nbsp,
      eve.icons.listchars.space,
      eve.icons.listchars.trail
    )
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
    title = " " .. state.title .. " ",
    title_pos = "center",
    border = { " ", " ", " ", " ", " ", " ", " ", " " }, --- "rounded", --- { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
    style = "minimal",
  }
  if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
    vim.api.nvim_win_set_config(winnr_input, wincfg_input)
    vim.api.nvim_win_set_buf(winnr_input, bufnr_input)
  else
    winnr_input = vim.api.nvim_open_win(bufnr_input, true, wincfg_input)
    self._winnr_input = winnr_input
  end
  vim.wo[winnr_input].number = false
  vim.wo[winnr_input].relativenumber = false
  vim.wo[winnr_input].signcolumn = "yes:1"
  vim.wo[winnr_input].winblend = 10
  vim.wo[winnr_input].winhighlight = INPUT_WIN_HIGHLIGHT
  vim.wo[winnr_input].wrap = false

  if winnr_cur ~= winnr_input and winnr_cur ~= winnr_preview then
    vim.api.nvim_tabpage_set_win(0, winnr_input)
  end
end

---@param raw_dimension                 fml.types.ui.search.IRawDimension
---@return nil
function M:change_dimension(raw_dimension)
  local old_dimension = self._dimension

  ---@type fml.types.ui.search.IDimension
  local dimension = {
    height = raw_dimension.height,
    max_width = raw_dimension.max_width or 0.8,
    max_height = raw_dimension.max_height or 0.8,
    width = raw_dimension.width,
    width_preview = raw_dimension.width_preview,
  }
  self._dimension = dimension

  if
    dimension.height ~= old_dimension.height
    or dimension.max_width ~= old_dimension.max_width
    or dimension.max_height ~= old_dimension.max_height
    or dimension.width ~= old_dimension.width
    or dimension.width_preview ~= old_dimension.width_preview
  then
    self.state.dirtier_dimension:mark_dirty()
  end
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  self.state.title = title
  local winnr = self:get_winnr_input() ---@type integer|nil
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
  self._preview_title = title
  local winnr = self:get_winnr_preview() ---@type integer|nil
  if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
    ---@type vim.api.keyset.win_config
    local win_conf_cur = vim.api.nvim_win_get_config(winnr)
    win_conf_cur.title = " " .. title .. " "
    vim.api.nvim_win_set_config(winnr, win_conf_cur)
  end
end

---@return nil
function M:close()
  self:hide()

  if self._destroy_on_close then
    self._alive = false
    self._input:destroy()
    self._main:destroy()

    if self._preview ~= nil then
      self._preview:destroy()
    end
  end

  if self._on_close ~= nil then
    self._on_close()
  end
end

---@return nil
function M:focus()
  local state = self.state ---@type fml.types.ui.search.IState
  local visible = state.visible:snapshot() ---@type boolean

  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local winnr_input = self:get_winnr_input() ---@type integer|nil
  local winnr_main = self:get_winnr_main() ---@type integer|nil

  if
    not visible
    or winnr_input == nil
    or winnr_main == nil
    or not vim.api.nvim_win_is_valid(winnr_input)
    or not vim.api.nvim_win_is_valid(winnr_main)
  then
    self:open()
    return
  end

  local winnr_preview = self:get_winnr_preview() ---@type integer|nil
  if winnr_cur ~= winnr_input and winnr_cur ~= winnr_preview then
    vim.schedule(function()
      if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
        vim.api.nvim_tabpage_set_win(0, winnr_input)
      end
    end)
  end
end

---@return integer|nil
function M:get_winnr_main()
  return self._winnr_main
end

---@return integer|nil
function M:get_winnr_input()
  return self._winnr_input
end

---@return integer|nil
function M:get_winnr_preview()
  return self._winnr_preview
end

---@return nil
function M:hide()
  local winnr = api_state.get_current_tab_winnr() ---@type integer
  vim.api.nvim_tabpage_set_win(0, winnr)

  local winnr_input = self._winnr_input ---@type integer|nil
  local winnr_main = self._winnr_main ---@type integer|nil
  local winnr_preview = self._winnr_preview ---@type integer|nil

  self._winnr_input = nil
  self._winnr_main = nil
  self._winnr_preview = nil
  self.state.visible:next(false)

  if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
    vim.api.nvim_win_close(winnr_input, true)
  end

  if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
    vim.api.nvim_win_close(winnr_main, true)
  end

  if winnr_preview ~= nil and vim.api.nvim_win_is_valid(winnr_preview) then
    vim.api.nvim_win_close(winnr_preview, true)
  end
end

---@return nil
function M:open()
  eve.widgets.push(self)
  self:show()
end

---@return nil
function M:reset_input(text)
  self._input:reset_input(text)
end

---@return nil
function M:resize()
  self.state.dirtier_dimension:mark_dirty()
end

---@return nil
function M:show()
  if not self._alive then
    eve.reporter.error({
      from = "fl.ui.search",
      subject = "show",
      message = "The widget has been destroyed, cannot open it again.",
      details = {
        alive = self._alive,
        dimension = self._dimension,
        state = self.state,
      },
    })
    return
  end

  local visible = self.state.visible:snapshot() ---@type boolean
  if not visible then
    self._input:create_buf_as_needed()
    self._main:render()
    if self._preview ~= nil then
      self._preview:render()
    end

    self._input:reset_input()
    self.state.visible:next(true)
  end
end

---@return nil
function M:toggle()
  local visible = self.state.visible:snapshot() ---@type boolean
  if visible then
    self:close()
  else
    self:open()
  end
end

---@return boolean
function M:visible()
  return self.state.visible:snapshot()
end

return M
