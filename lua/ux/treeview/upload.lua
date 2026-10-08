---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.upload" ---@type string

local async = require("ux.treeview.async")

---@class ux.treeview.Upload
---@field _native                       yoz.ux.treeview.Upload
local M = {}
M.__index = M

---@param native                        yoz.ux.treeview.Upload
---@return ux.treeview.Upload
function M.new(native)
  return setmetatable({ _native = native }, M)
end

---@param records                       ux.treeview.Records
---@return ux.treeview.IReply
function M:append(records)
  return self._native:append(records)
end

---@return stl.c.Future
function M:commit()
  return async.run(self._native:commit())
end

---@return nil
function M:dispose()
  self._native:dispose()
end

return M
