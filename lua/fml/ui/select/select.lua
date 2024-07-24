local std_array = require("fml.std.array")
local util = require("fml.std.util")
local Subscriber = require("fml.collection.subscriber")
local SelectInput = require("fml.ui.select.input")
local SelectMain = require("fml.ui.select.main")

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

---@class fml.ui.select.Select : fml.types.ui.select.ISelect
---@field public state                  fml.types.ui.select.IState
---@field public winnr_input            integer|nil
---@field public winnr_main             integer|nil
---@field protected input               fml.types.ui.select.IInput
---@field protected main                fml.types.ui.select.IMain
---@field protected max_width           number
---@field protected max_height          number
---@field protected width               number|nil
---@field protected height              number|nil
---@field protected _augroup_win_focus  integer
local M = {}
M.__index = M

---@class fml.types.ui.select.IProps
---@field public state                  fml.types.ui.select.IState
---@field public max_width              ?number
---@field public max_height             ?number
---@field public width                  ?number
---@field public height                 ?number
---@field public input_keymaps          ?fml.types.ui.IKeymap[]
---@field public main_keymaps           ?fml.types.ui.IKeymap[]
---@field public on_confirm             fml.types.ui.select.IOnConfirm
---@field public on_close               ?fml.types.ui.select.IOnClose
---@field public render_line            ?fml.types.ui.select.main.IRenderLine

---@param props                         fml.types.ui.select.IProps
---@return fml.ui.select.Select
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.select.IState
  local render_line = props.render_line ---@type fml.types.ui.select.main.IRenderLine|nil
  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.select.IOnConfirm
  local on_close_from_props = props.on_close ---@type fml.types.ui.select.IOnClose|nil
  local max_width = props.max_width or 0.8 ---@type number
  local max_height = props.max_height or 0.8 ---@type number
  local width = props.width ---@type number|nil
  local height = props.height ---@type number|nil
  local augroup_win_focus = util.augroup(state.uuid .. "_win_focus") ---@type integer

  ---@return nil
  local function on_close()
    if on_close_from_props ~= nil then
      on_close_from_props()
    end
    self:close()
  end

  ---@return nil
  local function on_confirm()
    local item, idx = state:get_current()
    if item ~= nil and idx ~= nil then
      if on_confirm_from_props(item, idx) then
        self.state:on_confirmed(item, idx)
        on_close()
      end
    end
  end

  ---@return nil
  local function on_main_renderered()
    self:sync_main_cursor()
  end

  ---@class fml.ui.select.select.actions
  local actions = {
    on_close = function()
      on_close()
    end,
    noop = util.noop,
    on_main_G = function()
      state:locate(#state:filter())
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
      local winnr_main = self.winnr_main ---@type integer|nil
      if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
        local lnum = vim.api.nvim_win_get_cursor(winnr_main)[1]
        state:locate(lnum)
        self:sync_main_cursor()
      end
    end,
  }

  ---@type fml.types.ui.IKeymap[]
  local input_keymaps = std_array.merge_multiple_array({
    { modes = { "i", "n", "v" }, key = "<cr>", callback = on_confirm, desc = "select: confirm" },
    { modes = { "n", "v" }, key = "q", callback = actions.on_close, desc = "select: close" },
    { modes = { "n", "v" }, key = "G", callback = actions.on_main_G, desc = "select: goto last line" },
    { modes = { "n", "v" }, key = "g", callback = actions.on_main_g, desc = "select: locate" },
    { modes = { "n", "v" }, key = "gg", callback = actions.on_main_gg, desc = "select: goto first line" },
    { modes = { "n", "v" }, key = "j", callback = actions.on_main_down, desc = "select: focus next item" },
    { modes = { "n", "v" }, key = "k", callback = actions.on_main_up, desc = "select: focus prev item" },
  }, props.input_keymaps or {})

  ---@type fml.types.ui.IKeymap[]
  local main_keymaps = std_array.merge_multiple_array({
    {
      modes = { "n", "v" },
      key = "<LeftRelease>",
      callback = actions.on_main_mouse_click,
      desc = "select: mouse click (main)",
    },
    { modes = { "n", "v" }, key = "<cr>", callback = on_confirm, desc = "select: confirm" },
    { modes = { "n", "v" }, key = "q", callback = actions.on_close, desc = "select: close" },
    { modes = { "n", "v" }, key = "G", callback = actions.on_main_G, desc = "select: goto last line" },
    { modes = { "n", "v" }, key = "g", callback = actions.on_main_g, desc = "select: locate" },
    { modes = { "n", "v" }, key = "gg", callback = actions.on_main_gg, desc = "select: goto first line" },
    { modes = { "n", "v" }, key = "j", callback = actions.on_main_down, desc = "select: focus next item" },
    { modes = { "n", "v" }, key = "k", callback = actions.on_main_up, desc = "select: focus prev item" },
  }, props.main_keymaps or {})

  ---@type fml.types.ui.select.IInput
  local input = SelectInput.new({
    state = state,
    keymaps = input_keymaps,
  })

  ---@type fml.types.ui.select.IMain
  local main = SelectMain.new({
    state = state,
    keymaps = main_keymaps,
    render_line = render_line,
    on_rendered = on_main_renderered,
  })

  self.state = state
  self.winnr_input = nil
  self.winnr_main = nil
  self.input = input
  self.main = main
  self.max_width = max_width
  self.max_height = max_height
  self.width = width
  self.height = height
  self._augroup_win_focus = augroup_win_focus

  state.ticker:subscribe(Subscriber.new({
    on_next = function()
      if self.state:is_visible() then
        self:open()
      end
    end,
  }))

  -- Detect focus on the main window and move cursor back to input
  vim.api.nvim_create_autocmd("WinEnter", {
    group = augroup_win_focus,
    callback = function()
      local winnr_cur = vim.api.nvim_get_current_win()
      if winnr_cur == self.winnr_main then
        if self.winnr_input ~= nil and vim.api.nvim_win_is_valid(self.winnr_input) then
          vim.api.nvim_tabpage_set_win(0, self.winnr_input)
        end
      end
    end,
  })
  return self
end

---@return nil
function M:sync_main_cursor()
  local lnum = self.main:place_lnum_sign() ---@type integer|nil
  if lnum ~= nil then
    local winnr_main = self.winnr_main ---@type integer|nil
    if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
      vim.api.nvim_win_set_cursor(winnr_main, { lnum, 0 })
    end
  end
end

---@param match_count                   integer
---@return nil
function M:create_wins_as_needed(match_count)
  local state = self.state ---@type fml.types.ui.select.IState
  local bufnr_input = self.input:create_buf_as_needed() ---@type integer
  local bufnr_main = self.main:create_buf_as_needed() ---@type integer
  local max_height = self.max_height <= 1 and math.floor(vim.o.lines * self.max_height) or self.max_height ---@type number
  local max_width = self.max_width <= 1 and math.floor(vim.o.columns * self.max_width) or self.max_width ---@type number

  local height = self.height or (#state.items + 3) ---@type number
  if height < 1 then
    height = math.floor(vim.o.lines * height)
  end
  height = math.min(max_height, math.max(3, height)) ---@type integer

  local width = self.width or state.max_width + 10 ---@type number
  if width < 1 then
    width = math.floor(vim.o.columns * width)
  end
  width = math.min(max_width, math.max(10, width)) ---@type integer

  local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
  local col = math.floor((vim.o.columns - width) / 2) ---@type integer
  local winnr_input = self.winnr_input ---@type integer|nil
  local winnr_main = self.winnr_main ---@type integer|nil

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
      self.winnr_main = winnr_main
    end

    vim.wo[winnr_main].cursorline = true
    vim.wo[winnr_main].number = false
    vim.wo[winnr_main].relativenumber = false
    vim.wo[winnr_main].signcolumn = "yes"
    vim.wo[winnr_main].winhighlight = MAIN_WIN_HIGHLIGHT
    self:sync_main_cursor()
  else
    self.winnr_main = nil
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
    self.winnr_input = winnr_input
  end
  vim.wo[winnr_input].number = false
  vim.wo[winnr_input].relativenumber = false
  vim.wo[winnr_input].signcolumn = "yes:1"
  vim.wo[winnr_input].winhighlight = INPUT_WIN_HIGHLIGHT

  ---! Set the default focused window to the input window.
  vim.api.nvim_tabpage_set_win(0, winnr_input)
end

---@return nil
function M:close()
  self.state:toggle_visible(false)

  local winnr_input = self.winnr_input ---@type integer|nil
  local winnr_main = self.winnr_main ---@type integer|nil

  self.winnr_input = nil
  if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
    vim.api.nvim_win_close(winnr_input, true)
  end

  self.winnr_main = nil
  if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
    vim.api.nvim_win_close(winnr_main, true)
  end

  vim.api.nvim_clear_autocmds({ group = self._augroup_win_focus })
end

function M:open()
  self.state:toggle_visible(true)
  local matches = self.state:filter() ---@type fml.types.ui.select.ILineMatch[]
  self:create_wins_as_needed(#matches)
  self.main:render()
end

---@return nil
function M:toggle()
  local visible = self.state:is_visible() ---@type boolean
  if visible then
    self:close()
  else
    self:open()
  end
end

return M
