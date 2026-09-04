---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.matcher" ---@type string

---@class era.dressing.hipattern.IDecoration
---@field public kind                   "highlight"|"inline_color"
---@field public coll                   integer
---@field public colr                   integer
---@field public hlgroup                string|nil
---@field public color                  string|nil

local rules = require("era.dressing.hipattern.rule").all

---@class era.dressing.hipattern.matcher
local M = {}

---@param line                          string
---@param filetype                      string
---@return era.dressing.hipattern.IDecoration[]
function M.match(line, filetype)
  local decorations = {} ---@type era.dressing.hipattern.IDecoration[]
  for _, rule in ipairs(rules) do
    local matches = rule.match(line, filetype)
    for _, match in ipairs(matches) do
      decorations[#decorations + 1] = match
    end
  end
  return decorations
end

return M
