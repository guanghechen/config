---@class fml.api.win
local M = require("fml.api.win.mod")

function M.resize_horizontal_minus()
  local step = vim.v.count1 or 1
  vim.cmd("resize -" .. step)
end

function M.resize_horizontal_plus()
  local step = vim.v.count1 or 1
  vim.cmd("resize +" .. step)
end

function M.resize_vertical_minus()
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize -" .. step)
end

function M.resize_vertical_plus()
  local step = vim.v.count1 or 1
  vim.cmd("vertical resize +" .. step)
end

M.split_horizontal = "<C-w>s"
M.split_vertical = "<C-w>v"
