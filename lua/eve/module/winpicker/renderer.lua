local hints = require("eve.module.winpicker.constant").hints

local winhighlight = table.concat({
  "FloatBorder:FloatBorder",
  "Normal:NormalFloat",
}, ",")

---@class eve.module.winpicker.renderer.IProps
---@field public char                   string

---@class eve.module.winpicker.Renderer
---@field public char                   string
---@field public hint                   string[]
---@field public bufnr_hint             integer|nil
---@field public winnr_hint             integer|nil
---@field public winnr_target           integer|nil
local M = {}
M.__index = M

M.renderers = {} ---@type table<string, eve.module.winpicker.Renderer>

---@param props                         eve.module.winpicker.renderer.IProps
---@return eve.module.winpicker.Renderer
function M.new(props)
  local char = props.char:lower() ---@type string
  if M.renderers[char] ~= nil then
    return M.renderers[char]
  end

  local hint = hints[char] ---@type string[]

  local self = setmetatable({}, M)
  self.char = char
  self.hint = hint
  self.bufnr_hint = nil
  self.winnr_hint = nil
  self.winnr_target = nil
  return self
end

---@protected
---@return integer
function M:create_buf_as_needed()
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
function M:show(winnr)
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
  vim.wo[winnr_hint].winhighlight = winhighlight
  vim.wo[winnr_hint].winfixbuf = true
  return winnr_hint
end

---@return nil
function M:hide()
  local winnr_hint = self.winnr_hint ---@type integer|nil
  self.winnr_hint = nil

  if winnr_hint ~= nil and vim.api.nvim_win_is_valid(winnr_hint) then
    vim.api.nvim_win_close(winnr_hint, true)
  end
end

return M
