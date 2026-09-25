---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.session" ---@type string

local async = require("stl.async")
local native_async = require("ux.treeview.async")
local Filetree = require("ux.filetree")

---@class era.m.explorer.Session
---@field data                          ux.filetree.Data
---@field state                         ux.treeview.State
---@field native                        yoz.ux.explorer.State
---@field views                         table<ux.filetree.View, fun(): nil>
---@field watch                         ?ux.filetree.IWatchStatus
---@field preparing                     boolean
---@field job                           ?yoz.ux.filetree.Job
---@field operation                     ?string
---@field results                       ux.filetree.IItemResult[]
---@field _disposed                     boolean
---@field _subscriptions                ?era.m.explorer.Subscriptions
local M = {}
M.__index = M

---@async
---@param future                        stl.c.Future
---@return any
function M.await(future)
  local value = future:await()
  if type(value) == "table" and value.kind == "Rejected" then
    error(value.error.code .. ": " .. value.error.message, 0)
  end
  return value
end

---@param error                         any
---@return nil
function M.report(error)
  stl.reporter.warn({ from = __module_name__, message = type(error) == "table" and error.message or tostring(error) })
end

---@param root                          string
---@param display                       ux.treeview.IDisplay
---@param data                          ?ux.filetree.Data
---@return stl.c.Future
function M.open(root, display, data)
  return async.run_future(function()
    local self = setmetatable({
      views = {},
      preparing = false,
      results = {},
      _disposed = false,
      _display_inputs = setmetatable({}, { __mode = "k" }),
    }, M)
    self.data = data or M.await(Filetree.open(root))
    local resource = M.await(self.data:resolve(root))
    self.state = M.await(self.data:create_state({ kind = "children_of", node = resource:node() }, display))
    self.native = yoz.ux.explorer.new(self.data._native, self.state._native)
    self._subscriptions = require("era.m.explorer.subscriptions").new(self)
    return self
  end)
end

---@param frame                         ?yoz.ux.treeview.Frame
---@return string|nil
function M:mode(frame)
  return self.native:mode(frame or self.state:snapshot())
end

---@param frame                         ?yoz.ux.treeview.Frame
---@return yoz.ux.filetree.Resource
function M:root(frame)
  frame = frame or self.state:snapshot()
  return self.data:inspect(frame:source(), frame:header().root.node)
end

---@param view                          ux.filetree.View
---@return yoz.ux.filetree.Resource|nil
function M:cursor(view)
  local frame = view:frame()
  if not frame or not vim.api.nvim_win_is_valid(view.winnr) then
    return nil
  end
  local node = frame:node_at(vim.api.nvim_win_get_cursor(view.winnr)[1])
  return node and self.data:inspect(frame:source(), node) or nil
end

---@param view                          ux.filetree.View
---@return yoz.ux.filetree.Resource
function M:target(view)
  local resource = self:cursor(view)
  if not resource then
    return self:root(view:frame())
  end
  if resource:info().directory then
    return resource
  end
  local source = resource:source()
  local parent = source:node(resource:node()).parent
  return parent and self.data:inspect(source, parent) or self:root(view:frame())
end

---@param view                          ux.filetree.View
---@param mark                          "toggle"|"select"|"copy"|"cut"
---@return stl.c.Future
function M:mark(view, mark)
  return view:range_action(function(frame, first, last, visual)
    return native_async.run(self.native:mark(frame, first, last, mark, visual))
  end)
end

---@param range                         era.m.explorer.IInputRange
---@return stl.c.Future
function M:inspect_range(range)
  return native_async.run(self.native:inspect_range(range.frame, range.first, range.last))
end

---@param node                          string
---@param reveal                        boolean
---@return stl.c.Future
function M:navigate(node, reveal)
  self._navigation_generation = (self._navigation_generation or 0) + 1
  return native_async.run(self.native:navigate(node, reveal)):map(function(value)
    if value.kind ~= "Rejected" then
      self._root_error = nil
    end
    return value
  end)
end

---@param path                          string
---@param reveal                        boolean
---@return stl.c.Future
function M:navigate_path(path, reveal)
  self._navigation_generation = (self._navigation_generation or 0) + 1
  local generation = self._navigation_generation
  return async.run_future(function()
    if reveal then
      path = M.await(native_async.run(self.native:reveal_path(path)))
    end
    local resource = M.await(self.data:resolve(path))
    if self._disposed or generation ~= self._navigation_generation then
      return { kind = "NoChange" }
    end
    local result = M.await(native_async.run(self.native:navigate(resource:node(), reveal)))
    self._root_error = nil
    return result
  end)
end

---@return stl.c.Future
function M:refresh()
  if self._subscriptions then
    self._subscriptions:refresh()
  end
  return self.data:refresh(self.state)
end

---@return boolean
function M:busy()
  return self.preparing or self.job ~= nil or self.state:status().locked
end

---@return nil
function M:notify()
  for _, changed in pairs(self.views) do
    changed()
  end
end

---@return string
function M:status_text()
  if self._root_error then
    return "root unavailable · <BS> parent"
  end
  if self.preparing then
    return self._preparation.label
  end
  if self.job and self.progress then
    if self.progress.confirmation then
      return self.progress.confirmation.kind == "prepare_move" and "preparing rename" or "confirm overwrite"
    end
    if self.progress.cancelling then
      return "stopping"
    end
    return string.format("%s %d items / %.1f MiB", self.operation, self.progress.results, self.progress.bytes / 1048576)
  end
  if self.watch and (self.watch.error or self.watch.limited) then
    return "watch limited · R refresh"
  end
  return self:mode() or ""
end

---@param view                          ux.filetree.View
---@param kind                          string
---@param options                       ?table
---@return stl.c.Future
function M:operate(view, kind, options)
  return require("era.m.explorer.jobs").start(self, view, kind, options or {})
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  for view in pairs(self.views) do
    view:detach()
  end
  self.views = {}
  if self._subscriptions then
    self._subscriptions:dispose(self)
    self._subscriptions = nil
  end
  if self.preparing then
    require("era.m.explorer.jobs").cancel(self)
  end
  -- The job registry retains this session until IO has reached its terminal state.
  self:_release()
end

---@return nil
function M:_release()
  if self._disposed and not self.job and not self.preparing then
    self.native, self.state, self.data = nil, nil, nil
  end
end

return M
