local nvim_tools = require("nvim_tools")
local json = require("fc.std.json")

---@class fml.std.oxi
---@field private                       nvim_tools table
---@field private                       json  fc.std.json
local M = {
  nvim_tools = nvim_tools,
  json = json,
}

return M
