local std_os = require("fml.std.os")

local PATH_SEP = std_os.path_sep() ---@type string

---@class fml.std.path
---@field SEP                           string
local M = {}

M.SEP = PATH_SEP ---@type string

return M
