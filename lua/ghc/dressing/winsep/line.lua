---@class ghc.dressing.winsep.line.highlights
local config = {
  h = {
    border = { " ", " ", "╭", "│", "╰", " ", " ", " " },
    hlgroup = table.concat({
      "FloatBorder:f_winsep_left_border",
      "Normal:f_winsep_normal",
    }, ","),
  },
  k = {
    border = { " ", " ", " ", " ", "╮", "─", "╭", " " },
    hlgroup = table.concat({
      "FloatBorder:f_winsep_top_border",
      "Normal:f_winsep_normal",
    }, ","),
  },
  l = {
    border = { "╮", " ", " ", " ", " ", " ", "╯", "│" },
    hlgroup = table.concat({
      "FloatBorder:f_winsep_right_border",
      "Normal:f_winsep_normal",
    }, ","),
  },
  j = {
    border = { "╰", "─", "╯", " ", " ", " ", " ", " " },
    hlgroup = table.concat({
      "FloatBorder:f_winsep_bottom_border",
      "Normal:f_winsep_normal",
    }, ","),
  },
}

---@alias ghc.dressing.winsep.line.Direction
---| "h" left
---| "k" top
---| "l" right
---| "j" bottom

---@class ghc.dressing.winsep.Line
---@field public cfg                    vim.api.keyset.win_config
---@field public winhighlight           string
---@field public winnr                  integer|nil
---@field public direction              ghc.dressing.winsep.line.Direction
local M = {}

---@param direction                     ghc.dressing.winsep.line.Direction
---@return ghc.dressing.winsep.Line
function M.new(direction)
  local self = setmetatable({}, { __index = M })

  ---@type vim.api.keyset.win_config
  local cfg = {
    relative = "editor",
    zindex = 1,
    width = 1,
    height = 1,
    row = 0,
    col = 0,
    focusable = false,
    border = config[direction].border,
    style = "minimal",
  }

  self.cfg = cfg
  self.winnr = nil
  self.direction = direction
  return self
end

---@return nil
function M:hide()
  if self.winnr ~= nil and vim.api.nvim_win_is_valid(self.winnr) then
    vim.api.nvim_win_close(self.winnr, true)
  end
  self.winnr = nil
end

---@param row                           integer
---@param col                           integer
---@param size                          integer
function M:move(row, col, size)
  local cfg = self.cfg ---@type vim.api.keyset.win_config
  local direction = self.direction ---@type ghc.dressing.winsep.line.Direction

  cfg.row = row
  cfg.col = col

  if direction == "h" or direction == "l" then
    cfg.height = size
  else
    cfg.width = size
  end
end

---@param bufnr integer
function M:show(bufnr)
  local winnr = self.winnr ---@type integer|nil
  local direction = self.direction ---@type ghc.dressing.winsep.line.Direction
  local cfg = self.cfg ---@type vim.api.keyset.win_config

  if winnr == nil or not vim.api.nvim_win_is_valid(winnr) then
    winnr = vim.api.nvim_open_win(bufnr, false, cfg)
    vim.wo[winnr].cursorline = false
    vim.wo[winnr].number = false
    vim.wo[winnr].signcolumn = "no"
    vim.wo[winnr].winblend = 100
    vim.wo[winnr].winhighlight = config[direction].hlgroup
    vim.wo[winnr].wrap = false
    self.winnr = winnr
  else
    vim.api.nvim_win_set_config(winnr, cfg)
  end
end

return M
