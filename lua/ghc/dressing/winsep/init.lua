local checks = require("eve.builtin.checks")
local state = require("eve.state")
local Line = require("ghc.dressing.winsep.line")

---@param direction                     ghc.dressing.winsep.line.Direction
---@return boolean
local function have_border_on_direction(direction)
  local winnum = vim.fn.winnr()
  return vim.fn.winnr(direction) ~= winnum and vim.fn.win_gettype(winnum) ~= "popup"
end

---@class ghc.dressing.Winsep
---@field protected left                   ghc.dressing.winsep.Line
---@field protected top                    ghc.dressing.winsep.Line
---@field protected right                  ghc.dressing.winsep.Line
---@field protected bottom                 ghc.dressing.winsep.Line
local Winsep = {}
Winsep.__index = Winsep

---@return ghc.dressing.Winsep
function Winsep.new()
  local self = setmetatable({}, Winsep)

  self.left = Line.new("h")
  self.top = Line.new("k")
  self.right = Line.new("l")
  self.bottom = Line.new("j")
  return self
end

---@return nil
function Winsep:show()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local win_pos = vim.api.nvim_win_get_position(winnr) ---@type integer[]
  local row = win_pos[1] ---@type integer
  local col = win_pos[2] ---@type integer
  local width = vim.fn.winwidth(0) - 1 ---@type integer
  local height = vim.fn.winheight(0) ---@type integer

  local h_exist = have_border_on_direction("h") ---@type boolean
  local k_exist = have_border_on_direction("k") ---@type boolean
  local l_exist = have_border_on_direction("l") ---@type boolean
  local j_exist = have_border_on_direction("j") ---@type boolean

  if vim.wo[winnr].winbar == "" then
    height = height - 1
  end

  if h_exist then
    col = col - 1
  end
  if k_exist then
    row = row - 1
  end
  if h_exist and l_exist then
    width = width + 1
  end
  if k_exist and j_exist then
    height = height + 1
  end
  if not k_exist and not j_exist then
    height = height - 1
  end

  if h_exist then
    self.left:move(row, col, height)
    self.left:show()
  else
    self.left:hide()
  end

  if k_exist then
    self.top:move(row, col, width)
    self.top:show()
  else
    self.top:hide()
  end

  if l_exist then
    self.right:move(row, col + width + 1, height)
    self.right:show()
  else
    self.right:hide()
  end

  if j_exist then
    self.bottom:move(row + height + 1, col, width)
    self.bottom:show()
  else
    self.bottom:hide()
  end
end

---@return nil
function Winsep:hide()
  self.left:hide()
  self.top:hide()
  self.right:hide()
  self.bottom:hide()
end

local winsep = Winsep.new() ---@type ghc.dressing.Winsep

---@param winnr                         integer
---@return boolean
local function should_show(winnr)
  local enabled = state.state.dressing.winsep:snapshot() ---@type boolean
  if not enabled then
    return false
  end

  if checks.is_win_floating(winnr) then
    return false
  end

  return true
end

vim.api.nvim_create_autocmd({ "WinEnter", "WinResized", "SessionLoadPost" }, {
  group = eve.nvim.augroup("winsep_refresh"),
  callback = function()
    local winnr = vim.api.nvim_get_current_win() ---@type integer
    if not should_show(winnr) then
      return
    end

    winsep:show()
  end,
})

eve.mvc.observe({ state.state.dressing.winsep }, function()
  local winnr = vim.api.nvim_get_current_win() ---@type integer
  if not should_show(winnr) then
    winsep:hide()
  else
    winsep:show()
  end
end)
