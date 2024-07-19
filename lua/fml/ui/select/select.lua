local Subscriber = require("fml.collection.subscriber")
local SelectInput = require("fml.ui.select.input")
local SelectMain = require("fml.ui.select.main")

---@class fml.ui.select.Select : fml.types.ui.select.ISelect
---@field public state                  fml.types.ui.select.IState
---@field protected input                  fml.types.ui.select.IInput
---@field protected main                   fml.types.ui.select.IMain
---@field protected max_width              number
---@field protected max_height             number
---@field protected winnr_input            integer|nil
---@field protected winnr_main             integer|nil
local M = {}
M.__index = M

---@class fml.types.ui.select.IProps
---@field public state                  fml.types.ui.select.IState
---@field public max_width              ?number
---@field public max_height             ?number
---@field public on_confirm             fml.types.ui.select.IOnConfirm
---@field public render_line            ?fml.types.ui.select.main.IRenderLine

---@param props                         fml.types.ui.select.IProps
---@return fml.ui.select.Select
function M.new(props)
  local self = setmetatable({}, M)

  local state = props.state ---@type fml.types.ui.select.IState
  local render_line = props.render_line ---@type fml.types.ui.select.main.IRenderLine|nil
  local on_confirm_from_props = props.on_confirm ---@type fml.types.ui.select.IOnConfirm
  local max_width = props.max_width or 0.8 ---@type number
  local max_height = props.max_height or 0.8 ---@type number

  ---@return nil
  local function on_confirm()
    local item, idx = state:get_current()
    if item ~= nil and idx ~= nil then
      if on_confirm_from_props(item, idx) then
        self:close()
      end
    end
  end

  ---@return nil
  local function on_main_renderered()
    self:sync_main_cursor()
  end

  local actions = {
    on_close = function()
      self:close()
    end,
    on_A = function()
      self:edit_input("A")
    end,
    on_a = function()
      self:edit_input("a")
    end,
    on_I = function()
      self:edit_input("I")
    end,
    on_i = function()
      self:edit_input("i")
    end,
    on_d = function()
      self:edit_input("d")
    end,
    on_x = function()
      self:edit_input("x")
    end,
    noop = function() end,
    on_input_down = function()
      self:focus_main()
    end,
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
  local input_keymaps = {
    { modes = { "n" }, key = "<cr>", callback = on_confirm, desc = "select: confirm" },
    { modes = { "n" }, key = "A", callback = actions.on_A, desc = "select: insert" },
    { modes = { "n" }, key = "a", callback = actions.on_a, desc = "select: insert" },
    { modes = { "n" }, key = "I", callback = actions.on_I, desc = "select: insert" },
    { modes = { "n" }, key = "i", callback = actions.on_i, desc = "select: insert" },
    { modes = { "n" }, key = "d", callback = actions.on_d, desc = "select: insert" },
    { modes = { "n" }, key = "x", callback = actions.on_x, desc = "select: insert" },
    { modes = { "n" }, key = "q", callback = actions.on_close, desc = "select: close" },
    { modes = { "n" }, key = "j", callback = actions.on_input_down, desc = "select: focus result" },
  }

  ---@type fml.types.ui.IKeymap[]
  local main_keymaps = {
    {
      modes = { "n" },
      key = "<LeftRelease>",
      callback = actions.on_main_mouse_click,
      desc = "select: mouse click (main)",
    },
    { modes = { "n" }, key = "<cr>", callback = on_confirm, desc = "select: confirm" },
    { modes = { "n" }, key = "k", callback = actions.on_main_up, desc = "select: focus prev item" },
    { modes = { "n" }, key = "A", callback = actions.on_A, desc = "select: insert" },
    { modes = { "n" }, key = "a", callback = actions.on_a, desc = "select: insert" },
    { modes = { "n" }, key = "I", callback = actions.on_I, desc = "select: insert" },
    { modes = { "n" }, key = "i", callback = actions.on_i, desc = "select: insert" },
    { modes = { "n" }, key = "d", callback = actions.on_d, desc = "select: insert" },
    { modes = { "n" }, key = "x", callback = actions.on_x, desc = "select: insert" },
    { modes = { "n" }, key = "v", callback = actions.noop, desc = "" },
    { modes = { "n" }, key = "q", callback = actions.on_close, desc = "select: close" },
    { modes = { "n" }, key = "G", callback = actions.on_main_G, desc = "select: goto last line" },
    { modes = { "n" }, key = "g", callback = actions.on_main_g, desc = "select: locate" },
    { modes = { "n" }, key = "gg", callback = actions.on_main_gg, desc = "select: goto first line" },
    { modes = { "n" }, key = "j", callback = actions.on_main_down, desc = "select: focus next item" },
    { modes = { "n" }, key = "k", callback = actions.on_main_up, desc = "select: focus prev item" },
  }

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
  self.input = input
  self.main = main
  self.max_width = max_width
  self.max_height = max_height
  self.winnr_input = nil
  self.winnr_main = nil

  state.ticker:subscribe(Subscriber.new({
    on_next = function()
      if self.state:is_visible() then
        self:open()
      end
    end,
  }))
  return self
end

---@param key                           string
---@return nil
function M:edit_input(key)
  local winnr_input = self.winnr_input ---@type integer|nil
  if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
    vim.api.nvim_tabpage_set_win(0, winnr_input)
    vim.api.nvim_feedkeys(key, "n", false)
  end
end

---@return nil
function M:focus_main()
  local winnr_main = self.winnr_main ---@type integer|nil
  if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
    vim.api.nvim_tabpage_set_win(0, winnr_main)
  end
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
  local height = math.min(max_height, #state.items + 3) ---@type integer
  local width = math.min(max_width, state.max_width + 10) ---@type integer
  local row = math.floor((vim.o.lines - height) / 2) - 1 ---@type integer
  local col = math.floor((vim.o.columns - width) / 2) ---@type integer
  local winnr_input = self.winnr_input ---@type integer|nil
  local winnr_main = self.winnr_main ---@type integer|nil

  if match_count > 0 then
    ---@type vim.api.keyset.win_config
    local wincfg_main = {
      relative = "editor",
      anchor = "NW",
      height = math.min(match_count + 1, height - 2),
      width = width,
      row = row + 2,
      col = col,
      focusable = true,
      title = "",
      border = { "│", " ", "│", "│", "╯", "─", "╰", "│" },
      style = "minimal",
    }
    if winnr_main ~= nil and vim.api.nvim_win_is_valid(winnr_main) then
      vim.api.nvim_win_set_config(winnr_main, wincfg_main)
      vim.api.nvim_win_set_buf(winnr_main, bufnr_main)
    else
      vim.api.nvim_open_win(bufnr_main, true, wincfg_main)
      winnr_main = vim.api.nvim_get_current_win()
      vim.wo[winnr_main].number = false
      vim.wo[winnr_main].relativenumber = false
      vim.wo[winnr_main].signcolumn = "yes"
      self.winnr_main = winnr_main
    end
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
    title = state.title,
    title_pos = "center",
    border = match_count < 1 and { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
      or { "╭", "─", "╮", "│", "│", " ", "│", "│" },
    style = "minimal",
  }
  if winnr_input ~= nil and vim.api.nvim_win_is_valid(winnr_input) then
    vim.api.nvim_win_set_config(winnr_input, wincfg_config)
    vim.api.nvim_win_set_buf(winnr_input, bufnr_input)
  else
    vim.api.nvim_open_win(bufnr_input, true, wincfg_config)
    winnr_input = vim.api.nvim_get_current_win()
    vim.wo[winnr_input].number = false
    vim.wo[winnr_input].relativenumber = false
    vim.wo[winnr_input].signcolumn = "yes"
    self.winnr_input = winnr_input
  end

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
