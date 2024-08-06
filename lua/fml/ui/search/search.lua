local Subscriber = require("fml.collection.subscriber")
local constant = require("fml.constant")
local api_state = require("fml.api.state")
local std_array = require("fml.std.array")
local util = require("fml.std.util")
local SearchInput = require("fml.ui.search.input")
local SearchMain = require("fml.ui.search.main")
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

local _search_current = nil ---@type fml.ui.search.Search|nil

-- Detect focus on the main window and move cursor back to input
vim.api.nvim_create_autocmd("WinEnter", {
  group = util.augroup("fml.ui.search:win_focus"),
  callback = function()
    if _search_current == nil then
      return
    end

    local visible = _search_current.state.visible:snapshot() ---@type boolean
    if not visible then
      return
    end

    local winnr_cur = vim.api.nvim_get_current_win() ---@type integer
    local winnr_main = _search_current:get_winnr_main() ---@type integer|nil
    local winnr_input = _search_current:get_winnr_input() ---@type integer|nil
    if winnr_cur == winnr_main then
      vim.schedule(function()
        if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
          vim.api.nvim_tabpage_set_win(0, winnr_input)
        end
      end)
    end
  end,
})

---@class fml.ui.search.Search : fml.types.ui.search.ISearch
---@field protected _winnr_input        integer|nil
---@field protected _winnr_main         integer|nil
---@field protected _input              fml.types.ui.search.IInput
---@field protected _main               fml.types.ui.search.IMain
---@field protected _max_width          number
---@field protected _max_height         number
---@field protected _width              number|nil
---@field protected _height             number|nil
---@field protected _on_close_callback  ?fml.types.ui.search.IOnClose
local M = {}
M.__index = M

---@class fml.types.ui.search.IProps
---@field public title                  string
---@field public input                  fml.types.collection.IObservable
---@field public input_history          fml.types.collection.IHistory|nil
---@field public fetch_items            fml.types.ui.search.IFetchItems
---@field public fetch_delay            ?integer
---@field public input_keymaps          ?fml.types.IKeymap[]
---@field public main_keymaps           ?fml.types.IKeymap[]
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
---@field public height                 ?number
---@field public on_confirm             fml.types.ui.search.IOnConfirm
---@field public on_close               ?fml.types.ui.search.IOnClose

---@param props                         fml.types.ui.search.IProps
---@return fml.ui.search.Search
function M.new(props)
  local self = setmetatable({}, M)

  local input_history = props.input_history ---@type fml.types.collection.IHistory|nil
  local max_width = props.max_width or 0.8 ---@type number
  local max_height = props.max_height or 0.8 ---@type number
  local width = props.width ---@type number|nil
  local height = props.height ---@type number|nil
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
      end
    end,
    on_main_mouse_dbclick = function()
      ---@diagnostic disable-next-line: invisible
      local winnr_main = self._winnr_main ---@type integer|nil
      if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
        local lnum = vim.api.nvim_win_get_cursor(winnr_main)[1]
        state:locate(lnum)
        self:sync_main_cursor()
        on_confirm()
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

  self.state = state
  self._winnr_input = nil
  self._winnr_main = nil
  self._input = input
  self._main = main
  self._max_width = max_width
  self._max_height = max_height
  self._width = width
  self._height = height
  self._on_close_callback = on_close_from_props

  state.dirty_main:subscribe(Subscriber.new({
    on_next = vim.schedule_wrap(function()
      self:draw()
    end),
  }))

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

  local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
  local col = math.floor((vim.o.columns - width) / 2) ---@type integer
  local winnr_input = self._winnr_input ---@type integer|nil
  local winnr_main = self._winnr_main ---@type integer|nil

  local match_count = #state.items ---@type integer
  if match_count > 0 then
    ---@type vim.api.keyset.win_config
    local wincfg_main = {
      relative = "editor",
      anchor = "NW",
      height = math.min(match_count + 1, height - 3),
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
    self:sync_main_cursor()
  else
    self._winnr_main = nil
    if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
      vim.api.nvim_win_close(winnr_main, true)
    end
  end

  ---@type vim.api.keyset.win_config
  local wincfg_config = {
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
    vim.api.nvim_win_set_config(winnr_input, wincfg_config)
    vim.api.nvim_win_set_buf(winnr_input, bufnr_input)
  else
    winnr_input = vim.api.nvim_open_win(bufnr_input, true, wincfg_config)
    self._winnr_input = winnr_input
  end
  vim.wo[winnr_input].number = false
  vim.wo[winnr_input].relativenumber = false
  vim.wo[winnr_input].signcolumn = "yes:1"
  vim.wo[winnr_input].winhighlight = INPUT_WIN_HIGHLIGHT

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

---@param force                         ?boolean
---@return nil
function M:draw(force)
  local state = self.state ---@type fml.types.ui.search.IState
  local visible = state.visible:snapshot() ---@type boolean
  if visible then
    self:create_wins_as_needed()
    self._main:render(force)
  end
end

---@return nil
function M:close()
  local winnr = api_state.get_current_tab_winnr() ---@type integer
  vim.api.nvim_tabpage_set_win(0, winnr)

  local winnr_input = self._winnr_input ---@type integer|nil
  local winnr_main = self._winnr_main ---@type integer|nil

  self._winnr_input = nil
  self._winnr_main = nil
  self.state.visible:next(false)

  if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
    vim.api.nvim_win_close(winnr_input, true)
  end

  if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
    vim.api.nvim_win_close(winnr_main, true)
  end

  if self._on_close_callback ~= nil then
    self._on_close_callback()
  end
end

---@return nil
function M:destroy()
  self:close()
  self._input:destroy()
  self._main:destroy()
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
