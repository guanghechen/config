---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.state" ---@type string

local async = require("ux.treeview.async")
local Task = require("ux.treeview.task")

---@class ux.treeview.State
---@field _native                       yoz.ux.treeview.State
---@field _data                         ux.treeview.Data
local M = {}
M.__index = M

---@param data                          ux.treeview.Data
---@param native                        yoz.ux.treeview.State
---@return ux.treeview.State
function M.new(data, native)
  return setmetatable({ _data = data, _native = native }, M)
end

---@return yoz.ux.treeview.Frame
function M:snapshot()
  return self._native:snapshot()
end

---@return ux.treeview.IStateStatus
function M:status()
  return self._native:status()
end

---@return ux.treeview.IDisplay
---@return ux.treeview.Revision
function M:display()
  return self._native:display()
end

---@param command                       ux.treeview.ICommand
---@param context                       ?ux.treeview.IContext
---@return stl.c.Future
function M:dispatch(command, context)
  return async.run(self._native:dispatch(command, context))
end

---@param root                          ux.treeview.IRoot
---@return stl.c.Future
function M:set_root(root)
  return self:dispatch({ kind = "set_root", root = root }, { expected_state = self:status().revisions.state })
end

---@param display                       ux.treeview.IDisplay
---@return stl.c.Future
function M:set_display(display)
  return self:dispatch({ kind = "set_display", display = display }, { expected_state = self:status().revisions.state })
end

---@param nodes                         string[]
---@param recursive                     boolean
---@return stl.c.Future
function M:select_node(nodes, recursive)
  return self:dispatch({ kind = "select_node", nodes = nodes, recursive = recursive })
end

---@param nodes                         string[]
---@param recursive                     boolean
---@return stl.c.Future
function M:deselect_node(nodes, recursive)
  return self:dispatch({ kind = "deselect_node", nodes = nodes, recursive = recursive })
end

---@param nodes                         string[]
---@param recursive                     boolean
---@param frame                         yoz.ux.treeview.Frame
---@return stl.c.Future
function M:toggle_node(nodes, recursive, frame)
  return self:dispatch({ kind = "toggle_node", nodes = nodes, recursive = recursive }, { frame = frame })
end

---@param nodes                         string[]
---@param value                         boolean
---@param recursive                     boolean
---@return stl.c.Future
function M:set_expanded(nodes, value, recursive)
  return self:dispatch({ kind = "set_expanded", nodes = nodes, value = value, recursive = recursive })
end

---@return stl.c.Future
function M:inspect_selection()
  return self:dispatch({ kind = "inspect_selection" })
end

---@return stl.c.Future
function M:clear_selection()
  return self:dispatch({ kind = "clear_selection" })
end

---@param deadline_ms                   ?integer
---@param selection_revision            ?ux.treeview.Revision
---@return stl.c.Future
function M:lock_selection(deadline_ms, selection_revision)
  return async
    .run(self._native:lock_selection(selection_revision or self:status().revisions.selection, deadline_ms))
    :map(function(result)
      return result.kind == "Locked" and Task.new(self, result.token) or result
    end)
end

return M
