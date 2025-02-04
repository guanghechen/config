local G = require("eve.builtin.G")
local env = require("eve.builtin.env")
local fn = require("eve.builtin.fn")
local tmux = require("eve.builtin.tmux")
local Subscriber = require("eve.collection.subscriber")
local Scheduler = require("eve.collection.scheduler")
local icons = require("eve.constant.icon")
local setting = require("eve.constant.setting")
local editor = require("eve.module.editor")
local state = require("eve.state")
local command = require("eve.command")

local SearchInput = require("fml.ux.search.input")
local SearchMain = require("fml.ux.search.main")
local SearchPreview = require("fml.ux.search.preview")

local EDITING_PREFIX = setting.EDITING_INPUT_PREFIX ---@type string

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

---@class fml.ux.search.ISearch : eve.t.ux.IWidget
---@field public context                fml.ux.search.IContext
---@field public change_input_title     fun(self: fml.ux.search.ISearch, title: string): nil
---@field public change_preview_title   fun(self: fml.ux.search.ISearch, title: string): nil
---@field public get_item_selected      fun(self: fml.ux.search.ISearch): fml.ux.search.IItem|nil, integer, string|nil
---@field public get_winnr_input        fun(self: fml.ux.search.ISearch): integer|nil
---@field public get_winnr_main         fun(self: fml.ux.search.ISearch): integer|nil
---@field public get_winnr_preview      fun(self: fml.ux.search.ISearch): integer|nil
---@field public mark_item_deleted      fun(self: fml.ux.search.ISearch, uuid: string): nil
---@field public reset_input            fun(self: fml.ux.search.ISearch, text: string): nil
---@field public show                   fun(self: fml.ux.search.ISearch): nil
---@field public toggle                 fun(self: fml.ux.search.ISearch): nil

---@alias fml.ux.search.IOnClose
---| fun(): nil

---@alias fml.ux.search.IOnConfirm
---| fun(widget: fml.ux.search.ISearch, items: fml.ux.search.IItem[]): nil

---@alias fml.ux.search.IOnInvisible
---| fun(): nil

---@alias fml.ux.search.IOnMainRendered
---| fun(): nil

---@alias fml.ux.search.IOnPreviewRendered
---| fun(): nil

---@alias fml.ux.search.IOnResume
---| fun(): nil

---@alias fml.ux.search.IFetchPreviewData
---| fun(item: fml.ux.search.IItem): fml.ux.search.preview.IData|nil

---@alias fml.ux.search.IPatchPreviewData
---| fun(item: fml.ux.search.IItem, last_item: fml.ux.search.IItem, last_data: fml.ux.search.preview.IData): fml.ux.search.preview.IData

---@alias fml.ux.search.IFetchDataCallback
---| fun(ok: true, data: fml.ux.search.IData|nil): nil
---| fun(ok: false, error: string|nil): nil

---@alias fml.ux.search.IFetchData
---| fun(input: string, force: boolean, callback: fml.ux.search.IFetchDataCallback): nil

---@class fml.ux.search.IData
---@field public items                  fml.ux.search.IItem[]
---@field public uuid_cursor            ?string
---@field public uuid_present           ?string

---@class fml.ux.search.IItem
---@field public group                  string|nil
---@field public parent                 string|nil
---@field public uuid                   string
---@field public text                   string
---@field public highlights             eve.t.IHighlightInline[]

---@class fml.ux.search.IProps
---@field public context                fml.ux.search.IContext
---@field public delay_render           ?integer
---@field public fetch_preview_data     ?fml.ux.search.IFetchPreviewData
---@field public input_keymaps          ?eve.t.IKeymap[]
---@field public main_keymaps           ?eve.t.IKeymap[]
---@field public patch_preview_data     ?fml.ux.search.IPatchPreviewData
---@field public preview_keymaps        ?eve.t.IKeymap[]
---@field public statusline_items       eve.t.ux.widget.IRawStatuslineItem[]
---@field public on_close               ?fml.ux.search.IOnClose
---@field public on_invisible           ?fml.ux.search.IOnInvisible
---@field public on_confirm             fml.ux.search.IOnConfirm
---@field public on_preview_rendered    ?fml.ux.search.IOnPreviewRendered

---@class fml.ux.search.Search : fml.ux.search.ISearch
---@field protected _input              fml.ux.search.IInput
---@field protected _main               fml.ux.search.IMain
---@field protected _preview            fml.ux.search.IPreview|nil
---@field protected _on_close           ?fml.ux.search.IOnClose
---@field protected _on_invisible       ?fml.ux.search.IOnInvisible
local M = {}
M.__index = M

---@param props                         fml.ux.search.IProps
---@return fml.ux.search.Search
function M.new(props)
  local self = setmetatable({}, M)

  local context = props.context ---@type fml.ux.search.IContext
  local common_keymaps = state.widget.get_keymaps(self, command.context_winnr) ---@type eve.t.IKeymap[]
  local statusline_items = {} ---@type eve.t.ux.widget.IStatuslineItem[]
  local delay_render = math.max(0, props.delay_render or 48) ---@type integer

  local raw_statusline_items = props.statusline_items ---@type eve.t.ux.widget.IRawStatuslineItem[]
  for idx, item in ipairs(raw_statusline_items) do
    local stl_state = item.state ---@type eve.collection.IObservable
    local symbol = item.symbol ---@type string
    local callback = item.callback ---@type fun(): nil
    local callback_fn = G.register_anonymous_fn(callback) or "" ---@type string

    ---@type eve.t.ux.widget.IStatuslineItem
    local statusline_item = { type = item.type, state = stl_state, symbol = symbol, callback_fn = callback_fn }
    table.insert(statusline_items, statusline_item)

    ---@type eve.t.IKeymap
    local keymap = {
      modes = { "n", "v" },
      key = "<leader>" .. idx,
      callback = callback,
      desc = item.desc,
      nowait = true,
    }
    table.insert(common_keymaps, keymap)
  end

  local on_confirm_from_props = props.on_confirm ---@type fml.ux.search.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.ux.search.IOnClose|nil
  local on_invisible_from_props = props.on_invisible ---@type fml.ux.search.IOnInvisible|nil

  ---@return nil
  local function on_confirm()
    local item = context:get_current() ---@type fml.ux.search.IItem|nil
    if item ~= nil then
      local items = { item } ---@type fml.ux.search.IItem[]
      on_confirm_from_props(self, items)

      local status = context.status:snapshot() ---@type eve.e.WidgetStatus
      if status ~= "visible" then
        local input_history = context.input_history ---@type eve.collection.IHistory|nil
        if input_history ~= nil then
          local top = input_history:top() ---@type string|nil
          if top ~= nil then
            top = fn.starts_with(top, EDITING_PREFIX) and top:sub(#EDITING_PREFIX + 1) or top ---@type string
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

  ---@class fml.ux.search.search.actions
  local actions = {
    focus_left = function()
      local pane = context.focused_pane_left ---@type string
      local winnr_pane = context["winnr_" .. pane] ---@type integer|nil
      if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
        context.focused_pane = pane
        local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
        if winnr ~= winnr_pane then
          vim.api.nvim_tabpage_set_win(0, winnr_pane)
        end
      end
    end,
    focus_right = function()
      local pane = context.focused_pane_right ---@type string
      local winnr_pane = context["winnr_" .. pane] ---@type integer|nil
      if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
        context.focused_pane = pane
        local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
        if winnr ~= winnr_pane then
          vim.api.nvim_tabpage_set_win(0, winnr_pane)
        end
      end
    end,
    focus_left_tmux = function()
      local is_zen_mode = state.status.tmux_zen_mode:snapshot() ---@type boolean
      if not is_zen_mode then
        tmux.change_pane("h")
      end
    end,
    focus_right_tmux = function()
      local is_zen_mode = state.status.tmux_zen_mode:snapshot() ---@type boolean
      if not is_zen_mode then
        tmux.change_pane("l")
      end
    end,
    focus_input = function()
      local pane = context.focused_pane_left ---@type string
      local winnr_pane = context.winnr_input ---@type integer|nil
      if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
        context.focused_pane = pane
        context.focused_pane_left = "input"
        local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
        if winnr ~= winnr_pane then
          vim.api.nvim_tabpage_set_win(0, winnr_pane)
        end
      end
    end,
    focus_main = function()
      local pane = context.focused_pane_left ---@type string
      local winnr_pane = context.winnr_main ---@type integer|nil
      if winnr_pane and vim.api.nvim_win_is_valid(winnr_pane) then
        context.focused_pane = pane
        context.focused_pane_left = "main"
        local winnr = vim.api.nvim_tabpage_get_win(0) ---@type integer
        if winnr ~= winnr_pane then
          vim.api.nvim_tabpage_set_win(0, winnr_pane)
        end
      end
    end,
    force_refresh = function()
      context.dirtier_data_cache:mark_dirty()
      context.dirtier_data:mark_dirty()
    end,
    toggle_current_selected = function()
      local uuid = context:get_current_uuid() ---@type string|nil
      if uuid ~= nil then
        context:toggle_item_selected(uuid)
      end
    end,
    toggle_visual_selected = function()
      local s_lnum, t_lnum = editor.get_visual_lnum_range() ---@type integer, integer
      return s_lnum, t_lnum
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
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      callback = actions.focus_main,
      desc = "search: focus up",
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      callback = env.IS_TMUX and actions.focus_left_tmux or fn.noop,
      desc = "search: focus left",
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>l",
      aliases = { "<D-l>", "<M-l>" },
      callback = actions.focus_right,
      desc = "search: focus right",
    },
    {
      active = context.multiple,
      modes = { "i", "n", "v" },
      key = "<Tab>",
      callback = actions.toggle_current_selected,
      desc = "search: toggle selected",
    },
  }

  ---@type eve.t.IKeymap[]
  local default_main_keymaps = {
    {
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      callback = actions.focus_input,
      desc = "search: focus down",
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>k",
      aliases = { "<D-k>", "<M-k>" },
      callback = actions.focus_input,
      desc = "search: focus up",
    },
    {
      modes = { "i", "n", "v" },
      key = "<C-a>h",
      aliases = { "<D-h>", "<M-h>" },
      callback = env.IS_TMUX and actions.focus_left_tmux or fn.noop,
      desc = "search: focus left",
    },
    {
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
      active = context.multiple,
      modes = { "i", "n" },
      key = "<Tab>",
      callback = actions.toggle_current_selected,
      desc = "search: toggle selected",
    },
    {
      active = context.multiple,
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
      modes = { "i", "n", "v" },
      key = "<C-a>j",
      aliases = { "<D-j>", "<M-j>" },
      callback = env.IS_TMUX and actions.focus_right_tmux or fn.noop,
      desc = "search: focus right",
    },
    {
      modes = { "i", "n", "v" },
      key = "<cr>",
      aliases = { "o" },
      callback = on_confirm,
      desc = "search: confirm",
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
      { modes = { "n", "v" }, key = "o", callback = fn.noop },
      { modes = { "n", "v" }, key = "O", callback = fn.noop },
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

  ---@type fml.ux.search.IInput
  local input = SearchInput.new({
    context = context,
    keymaps = input_keymaps,
  })

  ---@type fml.ux.search.IMain
  local main = SearchMain.new({
    context = context,
    keymaps = main_keymaps,
    on_rendered = on_main_renderered,
    delay_render = delay_render,
  })

  ---@type fml.ux.search.IPreview|nil
  local preview = nil
  if props.fetch_preview_data then
    preview = SearchPreview.new({
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

  local draw_wins_scheduler = Scheduler.new({
    name = "fml.ux.search.search.draw",
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
    Subscriber.new({
      on_next = function()
        trigger_draw_wins()
      end,
    }),
    true
  )

  context.state_has_matched:subscribe(
    Subscriber.new({
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
    Subscriber.new({
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
    Subscriber.new({
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
      Subscriber.new({
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
    Subscriber.new({
      on_next = function()
        local is_selected_dirty = context.dirtier_selected:is_dirty() ---@type boolean
        if is_selected_dirty then
          context:place_selected_sign()
        end
      end,
    }),
    true
  )

  if context.enable_multiline_input then
    context.input_line_count:subscribe(
      Subscriber.new({
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
  local context = self.context ---@type fml.ux.search.IContext
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
  local context = self.context ---@type fml.ux.search.IContext
  local dimension = context.dimension ---@type fml.ux.search.IDimension

  local bufnr_input = self._input:create_buf_as_needed() ---@type integer
  local bufnr_main = self._main:create_buf_as_needed() ---@type integer
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local screen_height = vim.o.lines ---@type integer
  local screen_width = vim.o.columns ---@type integer
  local winblend = state.theme.transparency:snapshot() and 0 or 10 ---@type integer

  ---@type number
  local max_height = dimension.max_height <= 1 and math.floor(dimension.max_height * screen_height)
    or dimension.max_height
  ---@type number
  local max_width = dimension.max_width <= 1 and math.floor(dimension.max_width * screen_width) or dimension.max_width

  local input_height = context.enable_multiline_input and math.max(1, math.min(3, context.input_line_count:snapshot()))
    or 1
  local input_height_with_borders = input_height + 1 ---@type integer

  local height = dimension.height or (#context.items + input_height_with_borders) ---@type number
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

  local match_count = #context.items ---@type integer
  local has_preview = self._preview ~= nil ---@type boolean
  local has_main = match_count > 0 or has_preview ---@type boolean

  local width_preview = dimension.width_preview or width ---@type integer
  if width_preview < 1 then
    width_preview = math.floor(width_preview * screen_width)
  end
  width_preview = has_preview and math.min(max_width - width - 2, math.max(10, width_preview)) or 0

  local row = math.min(prefer_row, math.floor((screen_height - height) / 2) - 1) ---@type integer
  local col = math.min(prefer_col, math.floor((screen_width - width - width_preview - 2) / 2)) ---@type integer
  local winnr_input = context.winnr_input ---@type integer|nil
  local winnr_main = context.winnr_main ---@type integer|nil
  local winnr_preview = context.winnr_preview ---@type integer|nil

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

  if self._preview then
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
        icons.listchars.eol,
        icons.listchars.lead,
        icons.listchars.nbsp,
        icons.listchars.space,
        icons.listchars.trail
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

  if winnr_cur ~= winnr_input and winnr_cur ~= winnr_preview and winnr_cur ~= winnr_main then
    vim.api.nvim_tabpage_set_win(0, winnr_input)
  end
end

---@param title                         string
---@return nil
function M:change_input_title(title)
  local context = self.context ---@type fml.ux.search.IContext
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
  local context = self.context ---@type fml.ux.search.IContext
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
  local context = self.context ---@type fml.ux.search.IContext

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
  local context = self.context ---@type fml.ux.search.IContext
  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  return winnr_cur == context.winnr_input or winnr_cur == context.winnr_main or winnr_cur == context.winnr_preview
end

---@return fml.ux.search.IItem|nil
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
  local context = self.context ---@type fml.ux.search.IContext
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
  state.widget.open(self)
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
