local nvim_tools = require("nvim_tools")
local json = require("fml.core.json")

---@class fml.core.oxi
---@field private                       nvim_tools table
---@field private                       json  fml.core.json
local M = { nvim_tools = nvim_tools, json = json }

return M
