local nvim_tools = require("nvim_tools")
local json = require("fc.std.json")

---@class fml.std.oxi
---@field protected nvim_tools          table
---@field protected json                fc.std.json
local M = {
  nvim_tools = nvim_tools,
  json = json,
}

return M
