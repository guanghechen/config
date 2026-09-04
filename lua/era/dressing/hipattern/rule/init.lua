---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.dressing.hipattern.rule" ---@type string

---@class era.dressing.hipattern.rule.IModule
---@field public match                  fun(line: string, filetype: string): era.dressing.hipattern.IDecoration[]

---@class era.dressing.hipattern.rule
local M = {}

M.all = {
  require("era.dressing.hipattern.rule.keyword"),
  require("era.dressing.hipattern.rule.color"),
  require("era.dressing.hipattern.rule.tailwind"),
  require("era.dressing.hipattern.rule.markdown"),
} ---@type era.dressing.hipattern.rule.IModule[]

return M
