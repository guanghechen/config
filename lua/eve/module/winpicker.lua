local __module_name__ = "eve.module.winpicker" ---@type string

local reporter = require("eve.builtin.reporter")
local hints = require("eve.constant.hint")

---@class eve.module.winpicker.config
local config = {
  chars = {
    "F",
    "J",
    "D",
    "K",
    "S",
    "L",
    "A",
    ";",
    "C",
    "M",
    "R",
    "U",
    "E",
    "I",
    "W",
    "O",
    "Q",
    "P",
  },
  winhighlight = table.concat({
    "FloatBorder:FloatBorder",
    "Normal:NormalFloat",
  }, ","),
}

---@return string|nil
local function get_user_input_char()
  local ok, c = pcall(vim.fn.getchar)

  if not ok then
    return
  end

  while type(c) ~= "number" do
    c = vim.fn.getchar()
  end

  return vim.fn.nr2char(c)
end

---@class eve.module.winpicker.Renderer
---@field public char                   string
---@field public hint                   string[]
---@field public bufnr_hint             integer|nil
---@field public winnr_hint             integer|nil
---@field public winnr_target           integer|nil
local Renderer = {}
Renderer.__index = Renderer

Renderer.renderers = {} ---@type table<string, eve.module.winpicker.Renderer>

---@param char                          string
---@return eve.module.winpicker.Renderer
function Renderer.new(char)
  if Renderer.renderers[char] ~= nil then
    return Renderer.renderers[char]
  end

  local hint = hints[char] ---@type string[]

  local self = setmetatable({}, Renderer)
  self.char = char
  self.hint = hint
  self.bufnr_hint = nil
  self.winnr_hint = nil
  self.winnr_target = nil
  return self
end

---@protected
---@return integer
function Renderer:create_buf_as_needed()
  local bufnr_hint = self.bufnr_hint ---@type integer|nil
  if bufnr_hint == nil or not vim.api.nvim_buf_is_valid(bufnr_hint) then
    bufnr_hint = vim.api.nvim_create_buf(false, true) ---@type integer
    self.bufnr_hint = bufnr_hint
  end

  vim.api.nvim_buf_set_lines(bufnr_hint, 0, 0, true, self.hint)
  return bufnr_hint
end

---@param winnr                         integer
---@return integer
function Renderer:show(winnr)
  local bufnr_hint = self:create_buf_as_needed() ---@type integer

  local width_target = vim.api.nvim_win_get_width(winnr) ---@type integer
  local height_target = vim.api.nvim_win_get_height(winnr) ---@type integer
  local width = 15 ---@type integer
  local height = #self.hint ---@type integer
  local row = math.floor((height_target - height) / 2) ---@type integer
  local col = math.floor((width_target - width) / 2) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg_hint = {
    relative = "win",
    win = winnr,
    anchor = "NW",
    focusable = true,
    title = "",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
  }

  local winnr_hint = self.winnr_hint ---@type integer|nil
  if winnr_hint == nil or not vim.api.nvim_win_is_valid(winnr_hint) then
    winnr_hint = vim.api.nvim_open_win(bufnr_hint, true, wincfg_hint) ---@type integer
    self.winnr_hint = winnr_hint

    vim.wo[winnr_hint].number = false
    vim.wo[winnr_hint].relativenumber = false
    vim.wo[winnr_hint].signcolumn = "no"
    vim.wo[winnr_hint].wrap = false
  else
    vim.wo[winnr_hint].winfixbuf = false
    vim.api.nvim_win_set_config(winnr_hint, wincfg_hint)
    vim.api.nvim_win_set_buf(winnr_hint, bufnr_hint)
  end

  vim.wo[winnr_hint].cursorline = false
  vim.wo[winnr_hint].winhighlight = config.winhighlight
  vim.wo[winnr_hint].winfixbuf = true
  return winnr_hint
end

---@return nil
function Renderer:hide()
  local winnr_hint = self.winnr_hint ---@type integer|nil
  self.winnr_hint = nil

  if winnr_hint ~= nil and vim.api.nvim_win_is_valid(winnr_hint) then
    vim.api.nvim_win_close(winnr_hint, true)
  end
end

---@class eve.module.winpicker
local M = {}

---@param filter                        fun(winnr: integer): boolean
---@param winnr_cur                     integer|nil
---@return integer|nil
function M.pick_window(filter, winnr_cur)
  local winnrs = vim.api.nvim_list_wins() ---@type integer[]
  local N = 0 ---@type integer
  for i = 1, #winnrs, 1 do
    local winnr = winnrs[i] ---@type integer
    if winnr ~= winnr_cur and filter(winnr) then
      N = N + 1 ---@type integer
      winnrs[N] = winnr
    end
  end

  if N < 1 then
    reporter.warn({
      from = __module_name__,
      subject = "pick_window",
      message = "No windows left to pick after filtering",
    })
    return nil
  end

  if N == 1 then
    return winnrs[1]
  end

  local renderers = {} ---@type table<integer, eve.module.winpicker.Renderer>
  for i = 1, N, 1 do
    local winnr = winnrs[i] ---@type integer
    local char = config.chars[i] ---@type string
    local renderer = Renderer.new(char:lower()) ---@type eve.module.winpicker.Renderer
    renderers[winnr] = renderer
  end

  for winnr, renderer in pairs(renderers) do
    renderer:show(winnr)
  end

  vim.cmd.redraw()
  local winnr_target = nil ---@type integer|nil

  local char = get_user_input_char() ---@type string|nil
  if char ~= nil then
    char = char:lower() ---@type string
    for winnr, renderer in pairs(renderers) do
      if char == renderer.char then
        winnr_target = winnr ---@type integer
        break
      end
    end
  end

  for _, renderer in pairs(renderers) do
    renderer:hide()
  end
  vim.cmd.redraw()

  return winnr_target
end

return M
