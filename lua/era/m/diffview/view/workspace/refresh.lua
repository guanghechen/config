---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.diffview.view.workspace.refresh" ---@type string

---@class era.m.diffview.view.workspace.refresh.IProps
---@field public debounce_ms             integer
---@field public is_stale               fun(): boolean
---@field public is_valid               fun(): boolean
---@field public run                    async fun(token: stl.c.CancellationToken): nil

---Owns refresh scheduling for one workspace view.
---@class era.m.diffview.view.workspace.Refresh
---@field protected _callbacks           (fun(): nil)[]
---@field protected _check_debounced     stl.timer.IDisposableCallable
---@field protected _current_token       stl.c.CancellationToken|nil
---@field protected _disposed            boolean
---@field protected _is_stale            fun(): boolean
---@field protected _is_valid            fun(): boolean
---@field protected _pending_check       boolean
---@field protected _pending_force       boolean
---@field protected _run                 async fun(token: stl.c.CancellationToken): nil
---@field protected _running             boolean
local Refresh = {}
Refresh.__index = Refresh

---@param props                          era.m.diffview.view.workspace.refresh.IProps
---@return era.m.diffview.view.workspace.Refresh
function Refresh.new(props)
  local self = setmetatable({}, Refresh)
  self._callbacks = {}
  self._current_token = nil
  self._disposed = false
  self._is_stale = props.is_stale
  self._is_valid = props.is_valid
  self._pending_check = false
  self._pending_force = false
  self._run = props.run
  self._running = false
  self._check_debounced = stl.timer.debounce(function()
    self:__request_check__()
  end, props.debounce_ms)
  return self
end

---@return nil
function Refresh:__request_check__()
  if self._disposed or not self._is_valid() then
    return
  end
  self._pending_check = true
  self:__drain__()
end

---@return nil
function Refresh:__complete_callbacks__()
  local callbacks = self._callbacks
  self._callbacks = {}
  for _, callback in ipairs(callbacks) do
    callback()
  end
end

---@return nil
function Refresh:__drain__()
  if self._disposed or self._running then
    return
  end

  if self._pending_force then
    self._pending_force = false
    -- A newer forced refresh covers watcher checks already queued before it starts.
    self._pending_check = false
    self:__start__()
    return
  end

  if self._pending_check then
    self._pending_check = false
    if self._is_valid() and self._is_stale() then
      self:__start__()
    end
  end
end

---@param token                          stl.c.CancellationToken
---@param succeeded                      boolean
---@return nil
function Refresh:__finish__(token, succeeded)
  if self._disposed or self._current_token ~= token then
    return
  end

  self._current_token = nil
  self._running = false

  if not self._is_valid() then
    self._callbacks = {}
    self._pending_check = false
    self._pending_force = false
    return
  end

  if self._pending_force then
    self:__drain__()
    return
  end

  if self._pending_check then
    self._pending_check = false
    if self._is_valid() and self._is_stale() then
      self:__start__()
      return
    end
  end

  if succeeded then
    self:__complete_callbacks__()
  else
    self._callbacks = {}
  end
end

---@return nil
function Refresh:__start__()
  if self._disposed or not self._is_valid() then
    return
  end

  local token = stl.c.CancellationToken.new()
  self._current_token = token
  self._running = true

  local ok, err = pcall(stl.async.run, function()
    local succeeded, run_err = xpcall(function()
      self._run(token)
    end, debug.traceback)
    self:__finish__(token, succeeded)
    if not succeeded then
      error(run_err, 0)
    end
  end)
  if not ok then
    self:__finish__(token, false)
    error(err, 0)
  end
end

---Request a refresh even if the current entries appear up to date.
---Requests received while one is running collapse into one trailing refresh.
---@param callback                       ?fun(): nil
---@return nil
function Refresh:request(callback)
  if self._disposed then
    return
  end
  if callback then
    self._callbacks[#self._callbacks + 1] = callback
  end
  self._pending_force = true
  self:__drain__()
end

---Request a debounced refresh only when the current entries are stale.
---@return nil
function Refresh:request_if_stale()
  if self._disposed then
    return
  end
  self._check_debounced()
end

---@return nil
function Refresh:dispose()
  if self._disposed then
    return
  end
  self._disposed = true
  self._check_debounced:dispose()
  if self._current_token then
    self._current_token:cancel()
    self._current_token = nil
  end
  self._callbacks = {}
  self._pending_check = false
  self._pending_force = false
  self._running = false
end

return Refresh
