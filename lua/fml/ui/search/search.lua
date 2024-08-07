local constant = require("fml.constant")
local api_state = require("fml.api.state")
local watch_observables = require("fml.fn.watch_observables")
local std_array = require("fml.std.array")
local util = require("fml.std.util")
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

local _search_current = nil ---@type fml.ui.search.Search|nil

---@class fml.ui.search.Search : fml.types.ui.search.ISearch
---@field protected _winnr_input        integer|nil
---@field protected _winnr_main         integer|nil
---@field protected _winnr_preview      integer|nil
---@field protected _input              fml.types.ui.search.IInput
---@field protected _main               fml.types.ui.search.IMain
---@field protected _preview            fml.types.ui.search.IPreview|nil
---@field protected _max_width          number
---@field protected _max_height         number
---@field protected _width              number|nil
---@field protected _height             number|nil
---@field protected _width_preview      number|nil
---@field protected _destroy_on_close   boolean
---@field protected _preview_title      string
---@field protected _on_close_callback  ?fml.types.ui.search.IOnClose
local M = {}
M.__index = M

---@class fml.types.ui.search.IProps
---@field public title                  string
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public fetch_items            fml.types.ui.search.IFetchItems
---@field public fetch_delay            ?integer
---@field public fetch_preview_data     ?fml.types.ui.search.preview.IFetchData
---@field public patch_preview_data     ?fml.types.ui.search.preview.IPatchData
---@field public input_keymaps          ?fml.types.IKeymap[]
---@field public main_keymaps           ?fml.types.IKeymap[]
---@field public preview_keymaps        ?fml.types.IKeymap[]
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
---@field public height                 ?number
---@field public width_preview          ?number
---@field public destroy_on_close       ?boolean
---@field public on_confirm             fml.types.ui.search.IOnConfirm
---@field public on_close               ?fml.types.ui.search.IOnClose
---@field public on_preview_rendered    ?fml.types.ui.search.preview.IOnRendered

---@param props                         fml.types.ui.search.IProps
---@return fml.ui.search.Search
function M.new(props)
  local self = setmetatable({}, M)

  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local max_width = props.max_width or 0.8 ---@type number
  local max_height = props.max_height or 0.8 ---@type number
  local width = props.width ---@type number|nil
  local height = props.height ---@type number|nil
  local width_preview = props.width_preview ---@type number|nil
  local destroy_on_close = not not props.destroy_on_close ---@type boolean
  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.search.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.types.ui.search.IOnClose|nil

  local state = SearchState.new({
    title = props.title,
    input = props.input,
    input_history = input_history,
    fetch_items = props.fetch_items,
    fetch_delay = props.fetch_delay,
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
          local input_cur = state.input:snapshot() ---@type string

          input_history:go(math.huge)
          local top = input_history:present() ---@type string|nil
          local prefix = constant.EDITING_INPUT_PREFIX ---@type string
          if top == nil or #top < #prefix or string.sub(top, 1, #prefix) ~= prefix then
            input_history:push(input_cur)
          else
            input_history:update_top(input_cur)
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
    on_close = function()
      on_close()
    end,
    noop = util.noop,
    on_main_G = function()
      state:locate(math.huge)
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
    on_main_mouse_click = function()
      ---@diagnostic disable-next-line: invisible
      local winnr_main = self._winnr_main ---@type integer|nil
      if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
        local lnum = vim.api.nvim_win_get_cursor(winnr_main)[1]
        state:locate(lnum)
        self:sync_main_cursor()

        vim.defer_fn(function()
          local winnr_input = self:get_winnr_input() ---@type integer|nil
          if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
            vim.api.nvim_tabpage_set_win(0, winnr_input)
          end
        end, 500)
      end
    end,
    on_main_mouse_dbclick = function()
      ---@diagnostic disable-next-line: invisible
      local winnr_main = self._winnr_main ---@type integer|nil
      if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
        local lnum = vim.api.nvim_win_get_cursor(winnr_main)[1]
        state:locate(lnum)
        self:sync_main_cursor()

        ---! To disable the unexpected which-key popup (the double click will enter visual mode, then the which-key will popup).
        vim.api.nvim_input("<Esc>")
        on_confirm()

        ---! To disable the unexpected which-key popup (the double click will enter visual mode, then the which-key will popup).
        vim.schedule(function()
          vim.api.nvim_input("<Esc>")
        end)
      end
    end,
  }

  ---@type fml.types.IKeymap[]
  local input_keymaps = std_array.concat({
    { modes = { "i", "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
    { modes = { "n", "v" }, key = "q", callback = actions.on_close, desc = "search: close" },
    { modes = { "n", "v" }, key = "G", callback = actions.on_main_G, desc = "search: goto last line" },
    { modes = { "n", "v" }, key = "g", callback = actions.on_main_g, desc = "search: locate" },
    { modes = { "n", "v" }, key = "gg", callback = actions.on_main_gg, desc = "search: goto first line" },
    { modes = { "n", "v" }, key = "j", callback = actions.on_main_down, desc = "search: focus next item" },
    { modes = { "n", "v" }, key = "k", callback = actions.on_main_up, desc = "search: focus prev item" },
  }, props.input_keymaps or {})

  ---@type fml.types.IKeymap[]
  local main_keymaps = std_array.concat({
    {
      modes = { "i", "n", "v" },
      key = "<LeftRelease>",
      callback = actions.on_main_mouse_click,
      nowait = true,
      desc = "search: mouse click (main)",
    },
    {
      modes = { "i", "n", "v" },
      key = "<2-LeftMouse>",
      callback = actions.on_main_mouse_dbclick,
      nowait = true,
      desc = "search: confirm",
    },
    { modes = { "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
    { modes = { "n", "v" }, key = "q", callback = actions.on_close, desc = "search: close" },
    { modes = { "n", "v" }, key = "G", callback = actions.on_main_G, desc = "search: goto last line" },
    { modes = { "n", "v" }, key = "g", callback = actions.on_main_g, desc = "search: locate" },
    { modes = { "n", "v" }, key = "gg", callback = actions.on_main_gg, desc = "search: goto first line" },
    { modes = { "n", "v" }, key = "j", callback = actions.on_main_down, desc = "search: focus next item" },
    { modes = { "n", "v" }, key = "k", callback = actions.on_main_up, desc = "search: focus prev item" },
  }, props.main_keymaps or {})

  ---@type fml.types.IKeymap[]
  local preview_keymaps = std_array.concat({
    { modes = { "n", "v" }, key = "<cr>", callback = on_confirm, desc = "search: confirm" },
    { modes = { "n", "v" }, key = "q", callback = actions.on_close, desc = "search: close" },
  }, props.preview_keymaps or {})

  ---@type fml.types.ui.search.IInput
  local input = SearchInput.new({
    uuid = state.uuid,
    input = state.input,
    input_history = state.input_history,
    keymaps = input_keymaps,
  })

  ---@type fml.types.ui.search.IMain
  local main = SearchMain.new({
    state = state,
    keymaps = main_keymaps,
    on_rendered = on_main_renderered,
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
      update_win_config = function(opts)
        local new_title = opts.title ---@type string
        local show_numbers = opts.show_numbers ---@type boolean

        ---@diagnostic disable-next-line: invisible
        self._preview_title = new_title
        local winnr = self:get_winnr_preview() ---@type integer|nil
        if winnr ~= nil and vim.api.nvim_win_is_valid(winnr) then
          ---@type vim.api.keyset.win_config
          local win_conf_cur = vim.api.nvim_win_get_config(winnr)
          win_conf_cur.title = " " .. new_title .. " "
          vim.api.nvim_win_set_config(winnr, win_conf_cur)
          vim.wo[winnr].number = show_numbers
        end
      end,
    })
  end

  self.state = state
  self._winnr_input = nil
  self._winnr_main = nil
  self._input = input
  self._main = main
  self._preview = preview
  self._max_width = max_width
  self._max_height = max_height
  self._width = width
  self._height = height
  self._width_preview = width_preview
  self._destroy_on_close = destroy_on_close
  self._preview_title = " preview "
  self._on_close_callback = on_close_from_props

  watch_observables({ state.dirty_main, state.dirty_preview }, function()
    vim.schedule(function()
      local is_dirty_main = state.dirty_main:snapshot() ---@type boolean|nil
      local is_dirty_preview = state.dirty_preview:snapshot() ---@type boolean|nil
      if is_dirty_main or is_dirty_preview then
        self:draw()
      end
    end)
  end, true)

  return self
end

---@return nil
function M:sync_main_cursor()
  local lnum = self._main:place_lnum_sign() ---@type integer|nil
  if lnum ~= nil then
    local winnr_main = self._winnr_main ---@type integer|nil
    if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
      vim.api.nvim_win_set_cursor(winnr_main, { lnum, 0 })
    end
  end
end

---@return nil
function M:create_wins_as_needed()
  local state = self.state ---@type fml.types.ui.search.IState
  local bufnr_input = self._input:create_buf_as_needed() ---@type integer
  local bufnr_main = self._main:create_buf_as_needed() ---@type integer
  local max_height = self._max_height <= 1 and math.floor(vim.o.lines * self._max_height) or self._max_height ---@type number
  local max_width = self._max_width <= 1 and math.floor(vim.o.columns * self._max_width) or self._max_width ---@type number

  local height = self._height or (#state.items + 3) ---@type number
  if height < 1 then
    height = math.floor(vim.o.lines * height)
  end
  height = math.min(max_height, math.max(3, height)) ---@type integer

  local width = self._width or state.max_width + 10 ---@type number
  if width < 1 then
    width = math.floor(vim.o.columns * width)
  end
  width = math.min(max_width, math.max(10, width)) ---@type integer

  local has_preview = self._preview ~= nil ---@type boolean

  local width_preview = self._width_preview or width ---@type integer
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
      height = has_preview and height - 3 or math.min(match_count + 1, height - 3),
      width = width,
      row = row + 3,
      col = col,
      focusable = true,
      title = "",
      border = "rounded", --- { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
      style = "minimal",
    }
    if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
      vim.api.nvim_win_set_config(winnr_main, wincfg_main)
      vim.api.nvim_win_set_buf(winnr_main, bufnr_main)
    else
      winnr_main = vim.api.nvim_open_win(bufnr_main, true, wincfg_main)
      self._winnr_main = winnr_main
    end

    vim.wo[winnr_main].cursorline = true
    vim.wo[winnr_main].number = false
    vim.wo[winnr_main].relativenumber = false
    vim.wo[winnr_main].signcolumn = "yes"
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
      border = "rounded", --- { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
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

    vim.wo[winnr_preview].cursorline = true
    vim.wo[winnr_preview].number = true
    vim.wo[winnr_preview].relativenumber = false
    vim.wo[winnr_preview].signcolumn = "yes:1"
    vim.wo[winnr_preview].winhighlight = PREVIEW_WIN_HIGHLIGHT
    vim.wo[winnr_preview].wrap = false
  end

  ---@type vim.api.keyset.win_config
  local wincfg_input = {
    relative = "editor",
    anchor = "NW",
    height = 1,
    width = width,
    row = row,
    col = col,
    focusable = true,
    title = " " .. state.title .. " ",
    title_pos = "center",
    border = "rounded", --- { "╭", "─", "╮", "│", "╯", "─", "╰", "│" },
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
  vim.wo[winnr_input].winhighlight = INPUT_WIN_HIGHLIGHT
  vim.wo[winnr_input].wrap = false

  ---! Set the default focused window to the input window.
  vim.api.nvim_tabpage_set_win(0, winnr_input)
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

---@param force                         ?boolean
---@return nil
function M:draw(force)
  local state = self.state ---@type fml.types.ui.search.IState
  local visible = state.visible:snapshot() ---@type boolean
  if visible then
    self:create_wins_as_needed()
    self._main:render(force)

    if self._preview ~= nil then
      self._preview:render(force)
    end
  end
end

---@return nil
function M:close()
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

  if self._destroy_on_close then
    self._input:destroy()
    self._main:destroy()

    if self._preview ~= nil then
      self._preview:destroy()
    end
  end

  if self._on_close_callback ~= nil then
    self._on_close_callback()
  end
end

---@return nil
function M:focus()
  local state = self.state ---@type fml.types.ui.search.IState
  local visible = state.visible:snapshot() ---@type boolean

  local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
  local winnr_main = self:get_winnr_main() ---@type integer|nil
  local winnr_input = self:get_winnr_input() ---@type integer|nil

  if
    not visible
    or winnr_main == nil
    or winnr_input == nil
    or not vim.api.nvim_win_is_valid(winnr_main)
    or not vim.api.nvim_win_is_valid(winnr_input)
  then
    self:open()
    return
  end

  if winnr_cur ~= winnr_main and winnr_cur ~= winnr_input then
    vim.schedule(function()
      if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
        vim.api.nvim_tabpage_set_win(0, winnr_input)
      end
    end)
  end
end

---@return nil
function M:open()
  if _search_current ~= self then
    if _search_current ~= nil then
      _search_current:close()
    end
    _search_current = self
  end

  local state = self.state ---@type fml.types.ui.search.IState
  state.visible:next(true)
  self._input:reset_input()
  self:draw()
end

---@return nil
function M:toggle()
  local state = self.state ---@type fml.types.ui.search.IState
  local visible = state.visible:snapshot() ---@type boolean
  if visible then
    self:close()
    state.visible:next(false)
  else
    self:open()
    state.visible:next(true)
  end
end

return M
