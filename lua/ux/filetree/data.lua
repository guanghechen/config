---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.filetree.data" ---@type string

local async = require("ux.treeview.async")
local State = require("ux.treeview.state")
local Treeview = require("ux.treeview")
local annotations = require("ux.filetree.annotations")
local filepath = require("ux.filetree.path")

---@class ux.treeview.Data
---@field _filetree_native              ?yoz.ux.filetree.Data

---@class ux.filetree.IJobObserver
---@field revision                      ?string
---@field on_update                     ?fun(status: ux.filetree.IJobStatus): nil

---@class ux.filetree.IRegistration
---@field observer                      ?ux.filetree.IObserver
---@field source_revision               ux.treeview.Revision

---@class ux.filetree.Data
---@field _native                       yoz.ux.filetree.Data
---@field _tree                         ux.treeview.Data
---@field root                          string
---@field _diagnostic_revision          ?integer
---@field _jobs                         table<yoz.ux.filetree.Job, ux.filetree.IJobObserver>
---@field _observers                    ux.filetree.IRegistration[]
---@field _on_effect                    ?fun(effect: ux.filetree.IEffect): nil
---@field _watch_hints                  table<ux.treeview.View, string>
---@field _watch_count                  integer
---@field _watch_revision               ?string
---@field _watch_error                  ?string
---@field _watching                     ?boolean
---@field _acknowledged                 ?ux.treeview.Revision
---@field _source_delivery              ?ux.treeview.Revision
local M = {}
M.__index = M

---@param native                        yoz.ux.filetree.Data
---@param options                       ?ux.filetree.IOptions
---@return ux.filetree.Data
function M.new(native, options)
  local self = setmetatable({
    _native = native,
    root = native:root(),
    _jobs = {},
    _observers = {},
    _on_effect = options and options.on_effect,
    _watch_hints = setmetatable({}, { __mode = "k" }),
    _watch_count = 0,
  }, M)
  self._tree = Treeview.from_native(native:treeview(), {
    on_effect = function(effect)
      self:_emit_effect(effect)
    end,
    after_poll = function(preparing)
      return self:_poll(preparing)
    end,
  })
  self._tree._filetree_native = native
  return self
end

---@param observer                      ux.filetree.IObserver
---@return stl.c.IUnsubscribable
function M:subscribe(observer)
  local registration = {
    observer = { on_effect = observer.on_effect, on_source_changed = observer.on_source_changed },
    source_revision = self:source():revision(),
  } ---@type ux.filetree.IRegistration
  -- Replace the list on registration changes so callbacks can safely unsubscribe or add observers.
  local observers = { unpack(self._observers) }
  observers[#observers + 1] = registration
  self._observers = observers
  return {
    unsubscribe = function()
      if not registration.observer then
        return
      end
      registration.observer = nil
      local retained = {}
      for _, current in ipairs(self._observers) do
        if current ~= registration then
          retained[#retained + 1] = current
        end
      end
      self._observers = retained
    end,
  }
end

---@param effect                        ux.filetree.IEffect
---@return nil
function M:_emit_effect(effect)
  local revision = effect.kind == "WatchStatus" and effect.status.revision or nil
  -- Subscribers commit their local state before the caller's handler runs.
  for _, registration in ipairs(self._observers) do
    if revision and revision ~= self._watch_revision then
      return
    end
    local observer = registration.observer
    if observer and observer.on_effect then
      local ok, error = pcall(observer.on_effect, effect)
      if not ok then
        async.report(error)
      end
    end
  end
  if revision and revision ~= self._watch_revision then
    return
  end
  if self._on_effect then
    local ok, error = pcall(self._on_effect, effect)
    if not ok then
      async.report(error)
    end
  elseif effect.kind == "WatchStatus" and next(self._tree._views) ~= nil then
    local status = effect.status
    if status.error then
      stl.reporter.warn({ from = __module_name__, message = status.error.message })
    elseif status.limited then
      stl.reporter.warn({
        from = __module_name__,
        message = "Some Filetree directories are not watched; refresh them manually",
      })
    end
  end
end

---@param preparing                     boolean
---@return boolean|nil
function M:_poll(preparing)
  local owner, native = self._tree, self._native
  if not preparing then
    local revision = owner:source():revision()
    if self._acknowledged ~= revision then
      owner._native:acknowledge_publication(revision)
      self._acknowledged = revision
    end
  end
  local hints, current, changed = {}, setmetatable({}, { __mode = "k" }), false
  for view in pairs(owner._views) do
    local cache = view._decorations
    if not view._closed and view._frame and cache and cache.frame == view._frame:id() then
      local signature = view._header.layout_revision .. ":" .. cache.first .. ":" .. cache.last
      current[view] = signature
      changed = changed or self._watch_hints[view] ~= signature
      hints[#hints + 1] = { frame = view._frame, first = cache.first, last = cache.last }
    end
  end
  if changed or #hints ~= self._watch_count then
    local ok, error = pcall(native.watch_visible, native, hints)
    if ok then
      self._watch_hints, self._watch_count, self._watch_error = current, #hints, nil
    elseif self._watch_error ~= tostring(error) then
      self._watch_error = tostring(error)
      async.report(error)
    end
  end
  local status = native:watch_status(self._watch_revision)
  if status then
    self._watch_revision, self._watching = status.revision, status.roots > 0
    self:_emit_effect({ kind = "WatchStatus", status = status })
  end
  local decorating = annotations.poll(owner, native)
  local finished_jobs = false
  for job, observer in pairs(self._jobs) do
    local status = job:status(observer.revision)
    if status then
      observer.revision = status.revision
      if status.terminal then
        self._jobs[job] = nil
        -- The final publication may have arrived after this turn's event drain.
        finished_jobs = true
      end
      if observer.on_update then
        local ok, error = pcall(observer.on_update, status)
        if not ok then
          async.report(error)
        end
      end
    end
  end
  if #self._observers > 0 then
    local revision = self:source():revision()
    self._source_delivery = revision
    for _, registration in ipairs(self._observers) do
      -- A callback may process a newer publication through a nested Neovim event loop.
      if self._source_delivery ~= revision then
        break
      end
      local observer = registration.observer
      if observer and registration.source_revision ~= revision then
        registration.source_revision = revision
        if observer.on_source_changed then
          local ok, error = pcall(observer.on_source_changed, revision)
          if not ok then
            async.report(error)
          end
        end
      end
    end
  end
  local busy = preparing or decorating or finished_jobs or native:is_busy()
  if
    not busy
    and next(self._jobs) == nil
    and not owner._pending_deadlines
    and next(owner._views) == nil
    -- Keep the notification lease until native watch teardown has published zero roots.
    and not self._watching
    and next(owner._works) == nil
    and next(owner._pending_reads) == nil
    and next(owner._queries) == nil
  then
    return nil
  end
  return busy
end

---@param job                           yoz.ux.filetree.Job
---@param on_update                     ?fun(status: ux.filetree.IJobStatus): nil
---@return yoz.ux.filetree.Job
function M:_track_job(job, on_update)
  self._jobs[job] = { on_update = on_update }
  async.watch(self._tree)
  return job
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
  return self:_track_job(self._native:start_operation(plan))
end

---@param plan                          ux.filetree.ICreatePlan
---@return yoz.ux.filetree.Job
function M:start_create(plan)
  return self:_track_job(self._native:start_create(plan))
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
    path = filepath.from_os(vim.api.nvim_buf_get_name(bufnr))
    if path == "" then
      path = nil
    else
      local current = vim.diagnostic.count(bufnr, { namespace = namespace })
      for severity = 1, 4 do
        counts[severity] = current[severity] or 0
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
