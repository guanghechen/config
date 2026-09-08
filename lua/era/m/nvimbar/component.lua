---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.component" ---@type string

local queue = require("era.m.nvimbar.queue")
local Future = require("stl.c.future")
local CancellationToken = require("stl.c.cancellation_token")

---@alias era.m.nvimbar.IComponentStatus "idle"|"queued"|"running"|"ready"|"failed"
---@alias era.m.nvimbar.IComponentSource era.m.nvimbar.IRawComponent|fun(): era.m.nvimbar.IRawComponent

---@class era.m.nvimbar.ISnapshot
---@field public version                integer
---@field public context                era.m.nvimbar.INvimbarContext
---@field public data                   any

---@class era.m.nvimbar.Component
---@field public status                 era.m.nvimbar.IComponentStatus
---@field public requested_version      integer
---@field public running_version        integer
---@field public snapshot               ?era.m.nvimbar.ISnapshot
---@field public definition             ?era.m.nvimbar.IRawComponent
---@field public error                  ?string
---@field protected _factory            ?fun(): era.m.nvimbar.IRawComponent
---@field protected _on_change          fun(context: era.m.nvimbar.INvimbarContext): nil
---@field protected _is_current         fun(context: era.m.nvimbar.INvimbarContext): boolean
---@field protected _on_stale           ?fun(): nil
---@field protected _disposed           boolean
---@field protected _queued             ?era.m.nvimbar.queue.ITask
---@field protected _context            ?era.m.nvimbar.INvimbarContext
---@field protected _active             ?{ version: integer, token: stl.c.CancellationToken }
---@field protected _force_refresh      boolean
---@field protected _format_error       ?string
---@field protected _notify_policy      ?era.m.nvimbar.INotifyPolicy
---@field protected _notify_pending     ?era.m.nvimbar.INvimbarContext
---@field protected _notified_at        ?number
local M = {}
M.__index = M

---@param left                          ?era.m.nvimbar.INvimbarContext
---@param right                         ?era.m.nvimbar.INvimbarContext
---@return boolean
local function same_scope(left, right)
  return left ~= nil
    and right ~= nil
    and left.winnr == right.winnr
    and left.bufnr == right.bufnr
    and left.tabnr == right.tabnr
    and left.filepath == right.filepath
    and left.cwd == right.cwd
end

---@param definition                    era.m.nvimbar.IRawComponent
---@param context                       era.m.nvimbar.INvimbarContext
---@param prev_context                  era.m.nvimbar.INvimbarContext
---@param snapshot                      any
---@return boolean
local function will_change(definition, context, prev_context, snapshot)
  if definition.will_change == nil then
    return true
  end
  local changed = definition.will_change(context, prev_context, snapshot)
  assert(type(changed) == "boolean", "Expected will_change to return a boolean")
  return changed
end

---@param policy                        ?era.m.nvimbar.INotifyPolicy
---@return era.m.nvimbar.INotifyPolicy
local function resolve_notification(policy)
  if policy == nil then
    return { strategy = "immediate" }
  end
  assert(type(policy) == "table", "Expected a nvimbar notification policy")
  local strategy, interval = policy.strategy, policy.interval
  assert(strategy == "immediate" or strategy == "debounce" or strategy == "throttle", "Invalid notification strategy")
  if strategy == "immediate" then
    assert(interval == nil, "Immediate notifications do not take an interval")
  else
    assert(
      type(interval) == "number" and interval > 0 and interval % 1 == 0,
      "Expected a positive notification interval"
    )
  end
  return { strategy = strategy, interval = interval }
end

---@param source                        era.m.nvimbar.IComponentSource
---@param on_change                     fun(context: era.m.nvimbar.INvimbarContext): nil
---@param is_current                    fun(context: era.m.nvimbar.INvimbarContext): boolean
---@param on_stale                      ?fun(): nil
---@param notify                        ?era.m.nvimbar.INotifyPolicy
---@return era.m.nvimbar.Component
function M.new(source, on_change, is_current, on_stale, notify)
  local policy = notify
  if policy == nil and type(source) == "table" then
    policy = source.notify
  end
  return setmetatable({
    status = "idle",
    requested_version = 0,
    running_version = 0,
    definition = type(source) == "table" and source or nil,
    _factory = type(source) == "function" and source or nil,
    _on_change = on_change,
    _is_current = is_current,
    _on_stale = on_stale,
    _disposed = false,
    _force_refresh = false,
    _notify_policy = (policy ~= nil or type(source) == "table") and resolve_notification(policy) or nil,
  }, M)
end

---@param context                       era.m.nvimbar.INvimbarContext
---@param force                         ?boolean
---@return nil
function M:request(context, force)
  if self._disposed then
    return
  end

  if not same_scope(self._context, context) then
    queue.unwatch(self)
    self._notify_pending = nil
    self._notified_at = nil
  end
  local definition = self.definition
  local snapshot = self.snapshot
  if
    not force
    and self.status == "ready"
    and snapshot ~= nil
    and same_scope(snapshot.context, context)
    and definition
    and definition.will_change
  then
    local ok, changed = pcall(will_change, definition, context, snapshot.context, snapshot.data)
    if not ok then
      local token = self:__cancel_work__()
      if token then
        token:cancel()
      end
      self._context = context
      self:__fail__(changed)
      return
    end
    if not changed then
      return
    end
  end

  self.requested_version = self.requested_version + 1
  self._context = context
  if force then
    self._force_refresh = true
  end
  if self.status ~= "running" then
    self:__enqueue__()
  end
end

---@param error                         any
---@return nil
function M:__fail__(error)
  local message = tostring(error)
  self.status = "failed"
  if self.error ~= message then
    stl.reporter.error({
      from = __module_name__,
      subject = "refresh",
      details = { component = self.definition and self.definition.name, error = message },
    })
  end
  self.error = message
  self:__notify__()
end

--- Notifications wake the owner; committed data remains available independently.
---@return nil
function M:__notify__()
  local context = assert(self._context)
  local policy = self._notify_policy
  if policy == nil or policy.strategy == "immediate" then
    self._on_change(context)
    return
  end

  local strategy = policy.strategy
  local interval = assert(policy.interval)
  local now = vim.uv.hrtime() / 1e6
  local remaining = self._notified_at and math.max(0, self._notified_at + interval - now) or 0
  if strategy == "throttle" and remaining == 0 then
    queue.unwatch(self)
    self._notify_pending = nil
    self._notified_at = now
    self._on_change(context)
  else
    local pending = self._notify_pending
    self._notify_pending = context
    if strategy == "debounce" or pending == nil then
      queue.watch(self, strategy == "debounce" and interval or remaining, function()
        local latest = self._notify_pending
        if self._disposed or latest == nil then
          return
        end
        self._notify_pending = nil
        self._notified_at = vim.uv.hrtime() / 1e6
        self._on_change(latest)
      end)
    end
  end
end

---@return nil
function M:__enqueue__()
  self.status = "queued"
  if self._queued then
    return
  end
  self._queued = queue.add(function()
    self._queued = nil
    if not self._disposed and self.status == "queued" then
      self:__run__()
    end
  end, self.snapshot ~= nil)
end

---@return nil
function M:__run__()
  local context = assert(self._context)
  local timeout = 3000
  local active = { version = self.requested_version, token = CancellationToken.new() }
  self._active = active
  self._force_refresh = false
  self.running_version = active.version
  self.status = "running"

  ---@return nil
  local function complete(ok, data)
    if self._disposed or self._active ~= active then
      return
    end
    self._active = nil
    queue.unwatch(active)
    active.token:cancel()
    if self._disposed or self.status ~= "running" then
      return
    end

    local pending = active.version ~= self.requested_version
    if pending and (not ok or self._force_refresh or not same_scope(context, self._context)) then
      self:__enqueue__()
      return
    end

    local valid, current = pcall(self._is_current, context)
    if not valid then
      self:__fail__(current)
    elseif not current then
      self.status = "idle"
      self._context = nil
      if self._on_stale then
        self._on_stale()
      end
    elseif not ok then
      self:__fail__(data)
    else
      if pending then
        -- A completed result can satisfy repeated requests for the same data.
        local checked, changed = pcall(will_change, self.definition, self._context, context, data)
        if not checked then
          self:__fail__(changed)
          return
        end
        if changed then
          self:__enqueue__()
          return
        end
      end
      self.snapshot = { version = self.requested_version, context = context, data = data }
      self.status = "ready"
      self.error = nil
      self:__notify__()
    end
  end

  local ok, result = xpcall(function()
    if not self._is_current(context) then
      return nil
    end
    local definition = self.definition
    if definition == nil then
      definition = assert(self._factory)()
      assert(type(definition) == "table" and type(definition.refresh) == "function", "Invalid nvimbar component")
      self._notify_policy = self._notify_policy or resolve_notification(definition.notify)
      self.definition = definition
      self._factory = nil
    end
    timeout = definition.timeout or 3000
    if definition.condition and not definition.condition(context) then
      return nil
    end
    return definition.refresh(context, active.token)
  end, debug.traceback)

  if not ok then
    complete(false, result)
  elseif getmetatable(result) == Future then
    queue.watch(active, timeout, function()
      complete(false, "Component refresh timed out")
    end)
    ---@cast result stl.c.Future
    result:finally(function(resolved, data)
      if vim.in_fast_event() then
        vim.schedule(function()
          complete(resolved, data)
        end)
      else
        complete(resolved, data)
      end
    end)
  else
    complete(true, result)
  end
end

--- Layout only reads a committed snapshot; pending work never runs from this method.
---@param context                       era.m.nvimbar.INvimbarContext
---@param width                         integer
---@return string
---@return integer
function M:format(context, width)
  local snapshot = self.snapshot
  if self._disposed or snapshot == nil or snapshot.data == nil or not same_scope(snapshot.context, context) then
    return "", 0
  end
  local ok, text, hltext = pcall(function()
    local text, hltext
    if self.definition.render then
      text, hltext = self.definition.render(snapshot.data, context, width)
    else
      text, hltext = snapshot.data.text, snapshot.data.hltext
    end
    assert(type(text) == "string" and type(hltext) == "string", "Invalid nvimbar layout result")
    return text, hltext
  end)
  if not ok then
    if self._format_error ~= tostring(text) then
      stl.reporter.error({
        from = __module_name__,
        subject = "layout",
        details = { component = self.definition.name, error = tostring(text) },
      })
    end
    self._format_error = tostring(text)
    text, hltext = "", ""
  else
    self._format_error = nil
  end
  return hltext, vim.api.nvim_strwidth(text)
end

---@return nil
function M:cancel()
  local token = self:prepare_cancel()
  if token then
    token:cancel()
  end
end

--- Commit cancellation before callers dispatch cleanup that may request new work.
---@return stl.c.CancellationToken|nil
function M:prepare_cancel()
  queue.unwatch(self)
  self._notify_pending = nil
  self._notified_at = nil
  return self:__cancel_work__()
end

---@protected
---@return stl.c.CancellationToken|nil
function M:__cancel_work__()
  self.requested_version = self.requested_version + 1
  local active = self._active
  local queued = self._queued
  self._active = nil
  self._queued = nil
  self.status = "idle"
  self._context = nil
  self._force_refresh = false
  if queued then
    queue.cancel(queued)
  end
  if active then
    queue.unwatch(active)
    return active.token
  end
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  self:cancel()
  self.snapshot = nil
  self._factory = nil
  self.definition = nil
  self._on_change = nil
  self._on_stale = nil
  self._is_current = nil
  self._notify_policy = nil
end

return M
