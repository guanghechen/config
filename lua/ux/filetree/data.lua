---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.filetree.data" ---@type string

local async = require("ux.treeview.async")
local State = require("ux.treeview.state")

---@class ux.treeview.Data
---@field _filetree_native              ?yoz.ux.filetree.Data

---@class ux.filetree.Data
---@field _native                       yoz.ux.filetree.Data
---@field _tree                         ux.treeview.Data
---@field root                          string
---@field _diagnostic_revision          ?integer
local M = {}
M.__index = M

---@param native                        yoz.ux.filetree.Data
---@param tree                          ux.treeview.Data
---@return ux.filetree.Data
function M.new(native, tree)
  tree._filetree_native = native
  return setmetatable({ _native = native, _tree = tree, root = native:root() }, M)
end

---@return yoz.ux.treeview.Source
function M:source()
  return self._native:source()
end

---@param root                          ?ux.treeview.IRoot
---@param display                       ?ux.treeview.IDisplay
---@return stl.c.Future
function M:create_state(root, display)
  return async.run(self._native:create_state(root, display)):map(function(value)
    return type(value) == "userdata" and State.new(self._tree, value) or value
  end)
end

---@param path                          string
---@return stl.c.Future
function M:resolve(path)
  return async.run(self._native:resolve(path))
end

---@param source                        yoz.ux.treeview.Source
---@param node                          string
---@return yoz.ux.filetree.Resource
function M:inspect(source, node)
  return self._native:inspect(source, node)
end

---@param resource                      yoz.ux.filetree.Resource
---@return stl.c.Future
function M:details(resource)
  return async.run(self._native:details(resource))
end

---@param source                        yoz.ux.filetree.Resource
---@param target                        yoz.ux.filetree.Resource
---@return stl.c.Future
function M:check_transfer_target(source, target)
  return async.run(self._native:check_transfer_target(source, target))
end

---@param state                         ux.treeview.State
---@return stl.c.Future
function M:refresh(state)
  return async.run(self._native:refresh(state._native))
end

---@return ux.filetree.IWatchStatus
function M:watch_status()
  return assert(self._native:watch_status())
end

---@param plan                          ux.filetree.IOperationPlan
---@return yoz.ux.filetree.Job
function M:start_operation(plan)
  if plan.task then
    plan = vim.tbl_extend("force", plan, {
      task = { state = plan.task.state._native, lock = plan.task.lock, cleanup = plan.task.cleanup },
    })
  end
  return self._native:start_operation(plan)
end

---@param plan                          ux.filetree.ICreatePlan
---@return yoz.ux.filetree.Job
function M:start_create(plan)
  return self._native:start_create(plan)
end

---@param root                          string
---@param revision                      string|integer
---@param snapshot                      ?yoz.git.StatusSnapshot
---@param ignored                       ?yoz.git.IgnoreCache
---@return stl.c.Future
function M:set_git(root, revision, snapshot, ignored)
  return async.run(self._native:set_git(root, revision, snapshot, ignored))
end

---@param namespace                     integer
---@param bufnr                         integer
---@param revision                      string|integer
---@param path                          ?string
---@param counts                        integer[]
---@return stl.c.Future
function M:set_diagnostics(namespace, bufnr, revision, path, counts)
  return async.run(self._native:set_diagnostics(namespace, bufnr, revision, path, counts))
end

---@param namespace                     integer
---@param bufnr                         integer
---@return stl.c.Future
function M:sync_diagnostics(namespace, bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  self._diagnostic_revision = (self._diagnostic_revision or 0) + 1
  local counts, path = { 0, 0, 0, 0 }, nil
  if vim.api.nvim_buf_is_valid(bufnr) then
    path = vim.api.nvim_buf_get_name(bufnr)
    if path == "" then
      path = nil
    else
      for _, diagnostic in ipairs(vim.diagnostic.get(bufnr, { namespace = namespace })) do
        local severity = diagnostic.severity or vim.diagnostic.severity.ERROR
        counts[severity] = counts[severity] + 1
      end
    end
  end
  return self:set_diagnostics(namespace, bufnr, self._diagnostic_revision, path, counts)
end

---@param frame                         yoz.ux.treeview.Frame
---@param first                         integer
---@param last                          integer
---@return stl.c.Future
function M:annotations(frame, first, last)
  return async.run(self._native:annotations(frame, first, last))
end

---@param frame                         yoz.ux.treeview.Frame
---@param row                           integer
---@param kind                          "git"|"diagnostic"|"error"|"warning"
---@param forward                       boolean
---@return stl.c.Future
function M:next_annotation(frame, row, kind, forward)
  return async.run(self._native:next_annotation(frame, row, kind, forward))
end

return M
