---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.task" ---@type string

local async = require("ux.treeview.async")

---@class ux.treeview.Task
---@field _state                        ux.treeview.State
---@field token                         string
local M = {}
M.__index = M

---@param state                         ux.treeview.State
---@param token                         string
---@return ux.treeview.Task
function M.new(state, token)
  return setmetatable({ _state = state, token = token }, M)
end

---@param retry                         ?boolean Retry failed ordinary children slots needed by this task.
---@return stl.c.Future
function M:prepare_sources(retry)
  return self._state:dispatch({ kind = "prepare_sources", lock = self.token, retry = retry })
end

---@param cleanup                       string
---@param successful                    string[]
---@return stl.c.Future
function M:unselect(cleanup, successful)
  return self._state:dispatch({ kind = "unselect", lock = self.token, cleanup = cleanup, successful = successful })
end

---@param cleanup                       string
---@param changes                       table[]
---@return stl.c.Future
function M:authorize_update(cleanup, changes)
  return async.run(self._state._native:authorize_update(self.token, cleanup, changes))
end

---@return stl.c.Future
function M:unlock()
  return async.run(self._state._native:unlock_selection(self.token))
end

return M
