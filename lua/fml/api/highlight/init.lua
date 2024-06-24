local Scheme = require("fml.api.highlight.scheme")
local resolve_hlgroup = require("fml.fn.resolve_hlgroup")

---@class fml.api.highlight
local M = {}

M.Scheme = Scheme
M.resolve_hlgroup = resolve_hlgroup

return M
