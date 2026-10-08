---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.explorer.session" ---@type string

local async = require("stl.async")
local native_async = require("ux.treeview.async")
local Filetree = require("ux.filetree")
local filepath = require("ux.filetree.path")

---@class era.m.explorer.Session
---@field data                          ux.filetree.Data
---@field state                         ux.treeview.State
---@field native                        yoz.ux.explorer.State
---@field views                         table<ux.filetree.View, fun(): nil>
---@field watch                         ?ux.filetree.IWatchStatus
---@field preparing                     boolean
---@field job                           ?yoz.ux.filetree.Job
---@field operation                     ?era.m.explorer.OperationKind
---@field results                       era.m.explorer.IItemResult[]
---@field issues                        era.m.explorer.IItemResult[]
---@field issues_omitted                integer
---@field _issue_bytes                  integer
---@field progress                      ?ux.filetree.IJobStatus
---@field _preparation                  ?era.m.explorer.IPreparation
---@field _direct_task                  ?ux.treeview.Task
---@field _result_offset                integer
---@field _counts                       era.m.explorer.IJobCounts
---@field _confirmation                 ?string
---@field _progress_key                 ?string
---@field _reported_root_error          ?string
---@field _finishing                    ?boolean
---@field _on_complete                  ?era.m.explorer.OnJobComplete
---@field _navigation_generation        ?integer
---@field _operation_sequence           ?integer
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
---@param workspace                     ?ux.filetree.Path
---@return stl.c.Future
function M.open(root, display, data, workspace)
  return async.run_future(function()
    local self = setmetatable({
      views = {},
      preparing = false,
      results = {},
      issues = {},
      issues_omitted = 0,
      _issue_bytes = 0,
      _result_offset = 0,
      _counts = { success = 0, failed = 0, skipped = 0, editor_failed = 0 },
      _disposed = false,
      _display_inputs = setmetatable({}, { __mode = "k" }),
    }, M)
    self.data = data or M.await(Filetree.open(root))
    local resource = M.await(self.data:resolve(root))
    local workspace_input = workspace or root
    local directory, requested = filepath.trim(workspace_input), filepath.trim(root)
    local source, node = resource:source(), resource:node()
    if directory ~= requested then
      local prefix = directory .. (directory:sub(-1) == "/" and "" or "/")
      if requested:sub(1, #prefix) ~= prefix then
        node = nil
      else
        -- Only descent preserves this observed ancestry; '..' after a symlink can leave the workspace.
        for component in requested:sub(#prefix + 1):gmatch("[^/]+") do
          if component == ".." then
            node = nil
            break
          elseif component ~= "." then
            node = source:node(node).parent
            if not node then
              break
            end
          end
        end
      end
    end
    if node then
      workspace_input = node == resource:node() and resource or self.data:inspect(source, node)
    end
    self.state = M.await(self.data:create_state({ kind = "children_of", node = resource:node() }, display))
    -- Keep an observed occurrence even if another owner renames it before this state is created.
    self.native = yoz.ux.explorer.new(self.data._native, self.state._native, workspace_input)
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
  end, false)
end

---@param frame                         yoz.ux.treeview.Frame
---@param node                          string
---@param kind                          "toggle"|"recursive"|"collapse"
---@return stl.c.Future
function M:fold(frame, node, kind)
  self.state:note_navigation()
  return native_async.run(self.native:fold(frame, node, kind))
end

---@return stl.c.Future
function M:cancel_transfer_or_clear_selection()
  return native_async.run(self.native:cancel_transfer_or_clear_selection())
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

---@return stl.c.Future
function M:navigate_parent()
  self._navigation_generation = (self._navigation_generation or 0) + 1
  return native_async.run(self.native:navigate_parent()):map(function(value)
    if value.kind ~= "Rejected" then
      self._root_error = nil
    end
    return value
  end)
end

---@param path                          string
---@param reveal                        boolean
---@param valid                         ?fun(): boolean
---@return stl.c.Future
function M:navigate_path(path, reveal, valid)
  self._navigation_generation = (self._navigation_generation or 0) + 1
  local generation = self._navigation_generation
  ---@return boolean
  local function current()
    return not self._disposed and generation == self._navigation_generation and (not valid or valid())
  end
  return async.run_future(function()
    if not current() then
      return { kind = "NoChange" }
    end
    if reveal then
      path = M.await(native_async.run(self.native:reveal_path(path)))
    end
    local resource ---@type yoz.ux.filetree.Resource|nil
    for attempt = 1, 3 do
      if not current() then
        return { kind = "NoChange" }
      end
      local result = self.data:resolve(path):await()
      if not current() then
        return { kind = "NoChange" }
      end
      if type(result) ~= "table" or result.kind ~= "Rejected" then
        resource = result
        break
      end
      -- Read-only path navigation can observe again after an overlapping publication.
      -- Destructive operations retain their captured resource and never use this retry.
      if result.error.code ~= "Stale" or attempt == 3 then
        error(result.error.code .. ": " .. result.error.message, 0)
      end
    end
    local result = M.await(native_async.run(self.native:navigate(assert(resource):node(), reveal)))
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

---@param frame                         yoz.ux.treeview.Frame
---@return nil
function M:observe_root(frame)
  if not self.state._native:applicable(frame) then
    return
  end
  local root = frame:header().root.node
  local node = frame:source():node(root)
  local error = node and node.error
  local key = error and table.concat({ root, error.code, error.message }, "\0") or nil
  if key == self._reported_root_error then
    return
  end
  self._reported_root_error = key
  if error then
    M.report("Directory scan failed: " .. error.message .. "\nPress R in Explorer to retry.")
  end
end

---@return string
---@return "error"|"progress"|nil priority
function M:status_text()
  if self._root_error then
    return "root unavailable · <BS> parent"
  end
  if self.preparing then
    return self._preparation.label, "progress"
  end
  if self.job and self.progress then
    if self.progress.confirmation then
      return self.progress.confirmation.kind == "prepare_move" and "preparing rename" or "confirm overwrite", "progress"
    end
    if self.progress.cancelling then
      return "stopping", "progress"
    end
    local progress = self.progress
    local size = string.format("%d B", progress.bytes)
    for _, unit in ipairs({ { 1073741824, "GiB" }, { 1048576, "MiB" }, { 1024, "KiB" } }) do
      if progress.bytes >= unit[1] then
        size = string.format("%.1f %s", progress.bytes / unit[1], unit[2])
        break
      end
    end
    local operation = progress.phase == "working" and self.operation or progress.phase
    return string.format("%s %d items / %s", operation, progress.processed, size), "progress"
  end
  local frame = self.state:snapshot()
  local root = frame:source():node(frame:header().root.node)
  if root and root.error then
    return root.child_count > 0 and "read failed · cached · R" or "read failed · R retry", "error"
  end
  if self.watch and (self.watch.error or self.watch.limited) then
    return "watch limited · R refresh"
  end
  return self:mode(frame) or ""
end

---@return string
function M:result_text()
  if not self.operation then
    return "No Explorer operations."
  end
  local counts = self._counts
  local editor = counts.editor_failed > 0
      and string.format(", %d editor sync issue%s", counts.editor_failed, counts.editor_failed == 1 and "" or "s")
    or ""
  return string.format(
    "%s: %d succeeded, %d failed, %d skipped%s%s",
    self.operation,
    counts.success,
    counts.failed,
    counts.skipped,
    editor,
    self.progress and self.progress.cancelled and " (cancelled)" or ""
  )
end

---@param view                          ux.filetree.View
---@param request                       era.m.explorer.IJobRequest
---@return stl.c.Future
function M:operate(view, request)
  local jobs = require("era.m.explorer.jobs")
  self._operation_sequence = (self._operation_sequence or 0) + 1
  local operation_sequence = self._operation_sequence
  if request.kind ~= "copy_to_path" and request.kind ~= "move_to_path" then
    return jobs.start(self, view, request)
  end
  local state = self.state
  local sequence = state:navigation_sequence()
  local generation = self._navigation_generation
  local focus_revoked = vim.api.nvim_get_current_win() ~= view.winnr
  local focus_watch
  ---@return nil
  local function clear_focus_watch()
    if focus_watch then
      vim.api.nvim_del_autocmd(focus_watch)
      focus_watch = nil
    end
  end
  ---@return boolean
  local function current()
    if
      focus_revoked
      or self._disposed
      or self.state ~= state
      or operation_sequence ~= self._operation_sequence
      or sequence ~= state:navigation_sequence()
      or not view:_valid()
      or view._desynced
      or vim.api.nvim_get_current_win() ~= view.winnr
      or self:busy()
    then
      return false
    end
    local cursor, observed = vim.api.nvim_win_get_cursor(view.winnr), view._observed_cursor
    -- CursorMoved may still be pending; surface publication updates observed itself.
    return not observed or cursor[1] == observed[1] and cursor[2] == observed[2]
  end
  if not focus_revoked then
    focus_watch = vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "BufUnload" }, {
      buf = view.bufnr,
      callback = function()
        focus_revoked = true
        clear_focus_watch()
      end,
    })
  end
  local on_complete = request.on_complete
  local operation = jobs.start(
    self,
    view,
    vim.tbl_extend("force", request, {
      on_complete = function(status, results)
        local item = results[#results]
        local succeeded = not status.error
          and not status.cancelled
          and type(status.cleanup) ~= "table"
          and #self.issues == 0
          and self.issues_omitted == 0
          and item
          and item.status == "success"
          and item.target
        if on_complete then
          local ok, err = pcall(on_complete, status, results)
          if not ok then
            clear_focus_watch()
            error(err, 0)
          end
        end
        if not succeeded or generation ~= self._navigation_generation or not current() then
          clear_focus_watch()
          return
        end
        -- A complete subtree keeps its root result last; result.node still identifies the source.
        local navigation = self:navigate_path(item.target, true, current)
        navigation:catch(M.report)
        navigation:finally(clear_focus_watch)
      end,
    })
  )
  operation:finally(function(ok, job)
    if not ok or not job then
      clear_focus_watch()
    end
  end)
  return operation
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
