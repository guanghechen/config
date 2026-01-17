local winhighlight = table.concat({
  "FloatBorder:FloatBorder",
  "Normal:NormalFloat",
}, ",")

---@class era.m.winpicker
---@field public char                   string
---@field public hint                   string[]
---@field public bufnr_hint             integer|nil
---@field public winnr_hint             integer|nil
---@field public winnr_target           integer|nil
local M = {}
M.__index = M

M.renderers = {} ---@type table<string, era.m.winpicker>

---@param char                          string
---@return era.m.winpicker
function M.new(char)
  if M.renderers[char] ~= nil then
    return M.renderers[char]
  end

  local hint = stl.winhint[char] ---@type string[]

  local self = setmetatable({}, M)
  self.char = char
  self.hint = hint
  self.bufnr_hint = nil
  self.winnr_hint = nil
  self.winnr_target = nil
  return self
end

----------------------------------------------------------------------------------------------------

---@protected
---@return integer
function M:__create_buf_as_needed__()
  local bufnr_hint = self.bufnr_hint ---@type integer|nil
  if bufnr_hint == nil or not vim.api.nvim_buf_is_valid(bufnr_hint) then
    bufnr_hint = vim.api.nvim_create_buf(false, true) ---@type integer
    vim.api.nvim_set_option_value("bufhidden", "hide", { buf = bufnr_hint })
    vim.api.nvim_set_option_value("buflisted", false, { buf = bufnr_hint })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr_hint })
    vim.api.nvim_set_option_value("filetype", stl.filetype.WINPICKER_MASK, { buf = bufnr_hint })
    vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr_hint })
    self.bufnr_hint = bufnr_hint
  end

  vim.api.nvim_buf_set_lines(bufnr_hint, 0, 0, true, self.hint)
  return bufnr_hint
end

---@param winnr                         integer
---@return integer
function M:show(winnr)
  local bufnr_hint = self:__create_buf_as_needed__() ---@type integer

  local width_target = vim.api.nvim_win_get_width(winnr) ---@type integer
  local height_target = vim.api.nvim_win_get_height(winnr) ---@type integer
  local width = 15 ---@type integer
  local height = #self.hint ---@type integer
  local row = math.floor((height_target - height) / 2) ---@type integer
  local col = math.floor((width_target - width) / 2) ---@type integer

  ---@type vim.api.keyset.win_config
  local wincfg_hint = {
    zindex = dot.win.resolve_zindex(),
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

    vim.w[winnr_hint].wintype = stl.nvim.win.TypeEnum.WINPICKER
    vim.w[winnr_hint][dot.var.N_WINLINE_DISABLED] = true

    vim.api.nvim_set_option_value("number", false, { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("relativenumber", false, { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("spell", false, { win = winnr_hint, scope = "local" })
    vim.api.nvim_set_option_value("wrap", false, { win = winnr_hint, scope = "local" })
  else
    vim.api.nvim_set_option_value("winfixbuf", false, { win = winnr_hint, scope = "local" })
    vim.api.nvim_win_set_config(winnr_hint, wincfg_hint)
    vim.api.nvim_win_set_buf(winnr_hint, bufnr_hint)
  end

  vim.api.nvim_set_option_value("cursorline", false, { win = winnr_hint, scope = "local" })
  vim.api.nvim_set_option_value("winfixbuf", true, { win = winnr_hint, scope = "local" })
  vim.api.nvim_set_option_value("winhighlight", winhighlight, { win = winnr_hint, scope = "local" })
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
