---@class ghc.action.win
local M = require("ghc.action.win.mod")

---@return nil
function M.resize_horizontal_minus()
  local step = vim.v.count1 or 1
  vim.cmd("resize -" .. step)
end

---@return nil
function M.resize_horizontal_plus()
  local step = vim.v.count1 or 1
  vim.cmd("resize +" .. step)
end

---@return nil
function M.resize_vertical_minus()
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize -" .. step)
end

---@return nil
function M.resize_vertical_plus()
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize +" .. step)
end
