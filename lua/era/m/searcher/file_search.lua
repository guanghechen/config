---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.searcher.file_search" ---@type string

---@class era.m.searcher.file_search.IRequest
---@field public options                yoz.search.ISearchInFilesOptions
---@field public context                unknown

---@class era.m.searcher.file_search.IActive
---@field public generation             integer
---@field public request                era.m.searcher.file_search.IRequest
---@field public job                    yoz.search.SearchInFilesJob

---@class era.m.searcher.file_search.IProps
---@field public name                   string
---@field public on_completed           fun(request: era.m.searcher.file_search.IRequest, result: yoz.search.ISearchFileResult): nil
---@field public on_error               fun(phase: string, error: unknown, request: era.m.searcher.file_search.IRequest|nil): nil
---@field public on_running             ?fun(request: era.m.searcher.file_search.IRequest): nil
---@field public is_current             ?fun(request: era.m.searcher.file_search.IRequest): boolean
---@field public start_job              ?fun(request: era.m.searcher.file_search.IRequest): yoz.search.SearchInFilesJob
---@field public set_interval           ?fun(fn: function, interval: integer): unknown|nil
---@field public clear_timer            ?fun(timer: unknown): nil
---@field public poll_interval          ?integer

---@class era.m.searcher.FileSearch
---@field public fullname               string
---@field protected _disposed           boolean
---@field protected _generation         integer
---@field protected _active             era.m.searcher.file_search.IActive|nil
---@field protected _pending            era.m.searcher.file_search.IActive|nil
---@field protected _timer              unknown|nil
---@field protected _poll_interval      integer
---@field protected _start_job          fun(request: era.m.searcher.file_search.IRequest): yoz.search.SearchInFilesJob
---@field protected _set_interval       fun(fn: function, interval: integer): unknown|nil
---@field protected _clear_timer        fun(timer: unknown): nil
---@field protected _is_current         fun(request: era.m.searcher.file_search.IRequest): boolean
---@field protected _on_completed       fun(request: era.m.searcher.file_search.IRequest, result: yoz.search.ISearchFileResult): nil
---@field protected _on_error           fun(phase: string, error: unknown, request: era.m.searcher.file_search.IRequest|nil): nil
---@field protected _on_running         (fun(request: era.m.searcher.file_search.IRequest): nil)|nil
local M = {}
M.__index = M

---@param props                         era.m.searcher.file_search.IProps
---@return era.m.searcher.FileSearch
function M.new(props)
  local name = props.name ---@type string
  local fullname = string.format("%s -> %s", name, __module_name__) ---@type string

  local self = setmetatable({}, M)
  self.fullname = fullname
  self._disposed = false
  self._generation = 0
  self._active = nil
  self._pending = nil
  self._timer = nil
  self._poll_interval = props.poll_interval or 16
  self._start_job = props.start_job
    or function(request)
      return yoz.search.start_search_in_files(request.options)
    end
  self._set_interval = props.set_interval or stl.timer.set_interval
  self._clear_timer = props.clear_timer or stl.timer.clear_timer
  self._is_current = props.is_current or function()
    return true
  end
  self._on_completed = props.on_completed
  self._on_error = props.on_error
  self._on_running = props.on_running
  return self
end

---@return integer
function M:invalidate()
  self:__health__()

  self._generation = self._generation + 1
  local active = self._active ---@type era.m.searcher.file_search.IActive|nil
  local ok, err = true, nil ---@type boolean, unknown
  if active ~= nil then
    ok, err = pcall(active.job.cancel, active.job)
  end
  self._pending = nil

  if not ok and active ~= nil then
    self:__finish__(active, "cancel", nil, err)
  end
  return self._generation
end

---@param generation                    integer
---@return boolean
function M:is_current_generation(generation)
  self:__health__()
  return generation == self._generation
end

---@param request                       era.m.searcher.file_search.IRequest
---@return nil
function M:submit(request)
  self:__health__()

  local queued = {
    generation = self._generation,
    request = request,
  } ---@type era.m.searcher.file_search.IActive

  local active = self._active ---@type era.m.searcher.file_search.IActive|nil
  if active == nil then
    self:__start__(queued)
    return
  end

  self._pending = queued
  local ok, err = pcall(active.job.cancel, active.job)
  if not ok then
    self:__finish__(active, "cancel", nil, err)
  end
end

---@param phase                         string
---@param error                         unknown
---@param request                       era.m.searcher.file_search.IRequest|nil
---@return nil
function M:fail_current(phase, error, request)
  self:__health__()
  self:__report__(self._generation, phase, error, request)
  if self._active == nil and self._pending == nil then
    self:__close_timer__()
  end
end

---@return nil
function M:dispose()
  if self._disposed then
    return
  end

  self._disposed = true
  self:__close_timer__()
  self._generation = self._generation + 1

  local active = self._active ---@type era.m.searcher.file_search.IActive|nil
  self._active = nil
  self._pending = nil
  if active ~= nil then
    pcall(active.job.cancel, active.job)
    pcall(active.job.dispose, active.job)
  end

  self._start_job = nil
  self._set_interval = nil
  self._clear_timer = nil
  self._is_current = nil
  self._on_completed = nil
  self._on_error = nil
  self._on_running = nil
end

---@return boolean
function M:isdisposed()
  return self._disposed
end

---@protected
---@param queued                        era.m.searcher.file_search.IActive
---@return nil
function M:__start__(queued)
  if not self:__is_current__(queued.generation, queued.request) then
    self:__advance__()
    return
  end

  local ok_timer, timer_err = self:__ensure_timer__()
  if not ok_timer then
    self:__report__(queued.generation, "timer", timer_err, queued.request)
    self:__advance__()
    return
  end

  local ok, job = pcall(self._start_job, queued.request)
  if not ok or job == nil then
    self:__report__(queued.generation, "start", ok and "start_job returned nil" or job, queued.request)
    self:__advance__()
    return
  end

  queued.job = job
  self._active = queued
end

---@protected
---@return nil
function M:__poll__()
  if self._disposed then
    return
  end

  local active = self._active ---@type era.m.searcher.file_search.IActive|nil
  if active == nil then
    self:__advance__()
    return
  end

  local ok, status, result, err = pcall(active.job.poll, active.job)
  if not ok then
    self:__finish__(active, "poll", nil, status)
    return
  end
  if status == "running" then
    self:__notify_running__(active)
    return
  end
  if status == "completed" then
    if type(result) ~= "table" or type(result.items) ~= "table" then
      self:__finish__(active, "poll", nil, "completed search returned an invalid result")
      return
    end
    self:__finish__(active, "completed", result, nil)
    return
  end
  if status == "cancelled" then
    self:__finish__(active, "cancelled", nil, nil)
    return
  end
  if status == "failed" then
    self:__finish__(active, "worker", nil, err or "search worker failed without an error")
    return
  end

  self:__finish__(active, "poll", nil, string.format("unknown search job status: %s", tostring(status)))
end

---@protected
---@param active                        era.m.searcher.file_search.IActive
---@return nil
function M:__notify_running__(active)
  local on_running = self._on_running
  if on_running == nil then
    return
  end

  local ok, err = pcall(on_running, active.request)
  if ok then
    return
  end

  self._on_running = nil
  self:__report__(active.generation, "progress", err, active.request)
end

---@protected
---@param active                        era.m.searcher.file_search.IActive
---@param phase                         string
---@param result                        yoz.search.ISearchFileResult|nil
---@param err                           unknown
---@return nil
function M:__finish__(active, phase, result, err)
  if self._active ~= active then
    return
  end

  self._active = nil
  pcall(active.job.dispose, active.job)

  local current = self:__is_current__(active.generation, active.request) ---@type boolean
  if current and phase == "completed" and result ~= nil then
    local ok, publish_err = xpcall(function()
      self._on_completed(active.request, result)
    end, debug.traceback)
    if not ok then
      self:__report__(active.generation, "publish", publish_err, active.request)
    end
  elseif current and phase ~= "cancelled" then
    self:__report__(active.generation, phase, err, active.request)
  end

  self:__advance__()
end

---@protected
---@return nil
function M:__advance__()
  if self._disposed or self._active ~= nil then
    return
  end

  local pending = self._pending ---@type era.m.searcher.file_search.IActive|nil
  self._pending = nil
  if pending ~= nil and pending.generation == self._generation then
    self:__start__(pending)
    return
  end
  self:__close_timer__()
end

---@protected
---@return boolean
---@return unknown|nil
function M:__ensure_timer__()
  if self._timer ~= nil then
    return true, nil
  end

  local ok, timer = pcall(self._set_interval, function()
    if self._disposed then
      return
    end

    local tick_ok, tick_err = xpcall(function()
      self:__poll__()
    end, debug.traceback)
    if tick_ok then
      return
    end

    local active = self._active ---@type era.m.searcher.file_search.IActive|nil
    if active ~= nil then
      self:__finish__(active, "timer", nil, tick_err)
    else
      self:__report__(self._generation, "timer", tick_err, nil)
      self:__close_timer__()
    end
  end, self._poll_interval)

  if not ok or timer == nil then
    return false, ok and "set_interval returned nil" or timer
  end
  self._timer = timer
  return true, nil
end

---@protected
---@return nil
function M:__close_timer__()
  local timer = self._timer
  self._timer = nil
  if timer ~= nil and self._clear_timer ~= nil then
    pcall(self._clear_timer, timer)
  end
end

---@protected
---@param generation                    integer
---@param phase                         string
---@param err                           unknown
---@param request                       era.m.searcher.file_search.IRequest|nil
---@return nil
function M:__report__(generation, phase, err, request)
  if not self:__is_current__(generation, request) or self._on_error == nil then
    return
  end
  pcall(self._on_error, phase, err, request)
end

---@protected
---@param generation                    integer
---@param request                       era.m.searcher.file_search.IRequest|nil
---@return boolean
function M:__is_current__(generation, request)
  if self._disposed or generation ~= self._generation then
    return false
  end
  if request == nil then
    return true
  end

  local ok, current = pcall(self._is_current, request)
  if ok then
    return not not current
  end

  if self._on_error ~= nil then
    pcall(self._on_error, "freshness", current, request)
  end
  return false
end

---@protected
---@return nil
function M:__health__()
  if self._disposed then
    error(string.format("[%s] already been disposed.", self.fullname))
  end
end

return M
