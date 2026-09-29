---@diagnostic disable-next-line: unused-local
local __module_name__ = "dot.theme.hlgroup.explorer.kanagawa" ---@type string

local unified = require("dot.theme.hlgroup.explorer.unified")

---@class dot.theme.hlgroup.explorer.kanagawa
local M = {}

---@param context                       stl.t.theme.IContext
---@return table<string, stl.t.theme.IHlgroup>
function M.gen_hlgroup_map(context)
  local hlgroup_map = unified.gen_hlgroup_map(context)

  return hlgroup_map
end

return M
