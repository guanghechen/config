local nvim_tools = require("nvim_tools")
local json = require("eve.std.json")

---@class eve.oxi
---@field protected nvim_tools          table
---@field protected json                eve.std.json
local M = {
  nvim_tools = nvim_tools,
  json = json,
}

return M
