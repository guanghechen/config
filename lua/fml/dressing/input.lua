---@class fml.dressing.input
local M = {}

M.complete = require("dot.module.input").complete
M.input = require("dot.module.input").open

local original_input = vim.ui.input
ark.fn.observe({ dot.context.flight.dressing_input }, function()
  local flag = dot.context.flight.dressing_input:snapshot() ---@type boolean
  if flag then
    vim.ui.input = M.input
  else
    vim.ui.input = original_input
  end
end, false)

return M
