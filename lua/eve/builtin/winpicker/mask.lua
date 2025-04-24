local hints = require("eve.builtin.winpicker.hint")

local winhighlight = table.concat({
  "FloatBorder:FloatBorder",
  "Normal:NormalFloat",
}, ",")

---@class eve.builtin.winpicker.Mask
---@field public char                   string
---@field public hint                   string[]
---@field public bufnr_hint             integer|nil
---@field public winnr_hint             integer|nil
---@field public winnr_target           integer|nil
local M = {}
M.__index = M

M.renderers = {} ---@type table<string, eve.builtin.winpicker.Mask>

---@param char                          string
---@return eve.builtin.winpicker.Mask
function M.new(char)
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
    vim.bo[bufnr_hint].bufhidden = "wipe"
    vim.bo[bufnr_hint].buflisted = false
    vim.bo[bufnr_hint].buftype = "nofile"
    vim.bo[bufnr_hint].filetype = eve.filetype.WINPICKER_MASK
    vim.bo[bufnr_hint].swapfile = false
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
    zindex = 1000,
    relative = "win",
    win = winnr,
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    focusable = false,
    title = "",
  }

  local winnr_hint = self.winnr_hint ---@type integer|nil
  if winnr_hint == nil or not vim.api.nvim_win_is_valid(winnr_hint) then
    wincfg_hint.noautocmd = true
    winnr_hint = vim.api.nvim_open_win(bufnr_hint, false, wincfg_hint) ---@type integer
    self.winnr_hint = winnr_hint

    vim.w[winnr_hint][eve.var.Names.WINTYPE] = eve.var.WinTypes.UX_WINPICKER
    vim.w[winnr_hint][eve.var.Names.WINLINE_DISABLED] = true
    vim.w[winnr_hint][eve.var.Names.FLAG_SOURCEFILE] = false

    vim.wo[winnr_hint].number = false
    vim.wo[winnr_hint].relativenumber = false
    vim.wo[winnr_hint].signcolumn = "no"
    vim.wo[winnr_hint].spell = false
    vim.wo[winnr_hint].wrap = false
  else
    vim.wo[winnr_hint].winfixbuf = false
    vim.api.nvim_win_set_config(winnr_hint, wincfg_hint)
    vim.api.nvim_win_set_buf(winnr_hint, bufnr_hint)
  end

  vim.wo[winnr_hint].cursorline = false
  vim.wo[winnr_hint].winfixbuf = true
  vim.wo[winnr_hint].winhighlight = winhighlight
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
