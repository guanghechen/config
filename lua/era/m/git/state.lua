---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.state" ---@type string

local REFRESH_THROTTLE_MS = 800 ---@type integer
local REFRESH_THROTTLE_MIN_MS = 100 ---@type integer

---@class era.m.git.state.IProps
---@field public collect                fun(token: stl.c.CancellationToken): stl.c.Future Resolves with yoz.git.StatusSnapshot.
---@field public snapshot               yoz.git.StatusSnapshot The status before the first collection.
---@field public throttle_ms            integer Longest window between collections.

---Repository status: coalesced, throttled collections and their publication.
---@class era.m.git.State
---@field public o_branch               stl.c.Observable<string>
---@field public o_refreshed            stl.c.Observable<era.m.git.state.IRefreshEvent>
---@field protected _active_callbacks   (fun(): nil)[] Callers the running collection settles.
---@field protected _collect            fun(token: stl.c.CancellationToken): stl.c.Future
---@field protected _collect_token      stl.c.CancellationToken|nil
---@field protected _disposed           boolean
---@field protected _elapsed_ms         number|nil Duration of the last collection.
---@field protected _longest_ms         integer
---@field protected _shortest_ms        integer
---@field protected _generation         integer
---@field protected _pending            boolean
---@field protected _pending_unknown    boolean
---@field protected _queued_callbacks   (fun(): nil)[] Callers waiting for a collection that has not started.
---@field protected _refresh_throttled  stl.timer.IDisposableCallable
---@field protected _refreshing         boolean
---@field protected _snapshot           yoz.git.StatusSnapshot
local State = {}
State.__index = State

---@param callbacks                     (fun(): nil)[]
---@return nil
local function run_callbacks(callbacks)
  for _, callback in ipairs(callbacks) do
    callback()
  end
end

---@param props                         era.m.git.state.IProps
---@return era.m.git.State
function State.new(props)
  local self = setmetatable({}, State)
  self.o_branch = stl.c.Observable.from_value("")
  self.o_refreshed = stl.c.Observable.from_value({ change_scope = "unknown", generation = 0 })
  self._active_callbacks = {}
  self._collect = props.collect
  self._collect_token = nil
  self._disposed = false
  self._generation = 0
  self._pending = false
  self._pending_unknown = false
  self._queued_callbacks = {}
  self._refreshing = false
  self._snapshot = props.snapshot
  self._longest_ms = props.throttle_ms
  self._shortest_ms = math.min(REFRESH_THROTTLE_MIN_MS, props.throttle_ms)
  self._refresh_throttled = stl.timer.throttle(function()
    self:__collect__()
  end, function()
    return self:__window__()
  end)
  return self
end

---Milliseconds before the next collection may start. Four times the last one's duration keeps a quick repository
---current while a slow one's event storms cannot occupy Git.
---@return integer
function State:__window__()
  return math.floor(math.max(self._shortest_ms, math.min(self._longest_ms, 4 * (self._elapsed_ms or 0))))
end

---@return nil
function State:__collect__()
  if self._disposed or self._refreshing or not self._pending then
    return
  end

  local change_scope = self._pending_unknown and "unknown" or "index" ---@type era.m.git.StatusChangeScope
  self._pending = false
  self._pending_unknown = false
  self._refreshing = true
  -- Requests arriving after capture need a later query, including those its settling callers make.
  self._active_callbacks = self._queued_callbacks
  self._queued_callbacks = {}

  local token = stl.c.CancellationToken.new()
  self._collect_token = token

  local started = vim.uv.hrtime()
  self._collect(token):finally(function(resolved, result)
    self._collect_token = nil
    self._elapsed_ms = (vim.uv.hrtime() - started) / 1000000

    if resolved and result and not self._disposed and not token:is_cancelled() then
      -- An unchanged status keeps its snapshot, so consumers can compare identities.
      if not self._snapshot:equals(result) then
        self._snapshot = result
      end
      self._generation = self._generation + 1
      self.o_refreshed:next({ change_scope = change_scope, generation = self._generation })
    elseif not self._disposed and not token:is_cancelled() then
      local reason = tostring(result or "Unknown error"):match("^[^\r\n]+") or "Unknown error" ---@type string
      stl.reporter.error({
        from = __module_name__,
        subject = "refresh",
        message = "Failed to refresh Git status: " .. reason,
      })
    end

    self._refreshing = false
    local callbacks = self._active_callbacks
    self._active_callbacks = {}
    run_callbacks(callbacks)

    if self._pending and not self._disposed then
      self._refresh_throttled()
    end
  end)
end

---@param change_scope                  era.m.git.StatusChangeScope
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future
function State:__request__(change_scope, token)
  return stl.c.Future.new(function(resolve)
    if self._disposed or (token and token:is_cancelled()) then
      resolve(nil)
      return
    end

    self._queued_callbacks[#self._queued_callbacks + 1] = function()
      resolve(nil)
    end
    -- Only an exclusively index-triggered collection can be compared with raw blob identities.
    -- Any coalesced request with broader or unknown provenance keeps the published event conservative.
    if change_scope ~= "index" then
      self._pending_unknown = true
    end
    self._pending = true
    if not self._refreshing then
      self._refresh_throttled()
    end
  end)
end

---@return yoz.git.StatusSnapshot
function State:snapshot()
  return self._snapshot
end

---Refreshes the status. Each caller waits for a collection started after its request; concurrent requests
---coalesce. The token only stops waiting when it is cancelled before the call; the shared collection runs on.
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with nil when refresh completes
function State:refresh(token)
  return self:__request__("unknown", token)
end

---Refreshes after a known Git index mutation, allowing consumers to compare blob identities.
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with nil when refresh completes
function State:refresh_index(token)
  return self:__request__("index", token)
end

---Cancels the running collection and settles every waiting caller; later requests settle at once.
---@return nil
function State:dispose()
  if self._disposed then
    return
  end

  self._disposed = true
  self._pending = false
  self._refresh_throttled:dispose()
  if self._collect_token then
    self._collect_token:cancel()
  end
  local callbacks = self._active_callbacks
  vim.list_extend(callbacks, self._queued_callbacks)
  self._active_callbacks = {}
  self._queued_callbacks = {}
  run_callbacks(callbacks)
end

---The repository status every consumer shares.
---@class era.m.git.state
local M = {}

M.State = State

local default = State.new({
  collect = function(token)
    return era.m.git.status.collect(nil, token)
  end,
  snapshot = era.m.git.status.empty(),
  throttle_ms = REFRESH_THROTTLE_MS,
})

M.o_branch = default.o_branch
M.o_refreshed = default.o_refreshed

---@return yoz.git.StatusSnapshot
function M.snapshot()
  return default:snapshot()
end

---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with nil when refresh completes
function M.refresh(token)
  return default:refresh(token)
end

---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future                 Resolves with nil when refresh completes
function M.refresh_index(token)
  return default:refresh_index(token)
end

---@return nil
function M.setup()
  local augroup = vim.api.nvim_create_augroup("DotModuleGitState", { clear = true }) ---@type integer

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      default:dispose()
    end,
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup,
    callback = function(args)
      if
        not dot.path.is_git_repo()
        or not vim.api.nvim_buf_is_valid(args.buf)
        or vim.api.nvim_get_option_value("buftype", { buf = args.buf }) ~= ""
      then
        return
      end
      -- The event path is the written target, which can differ from the buffer name.
      local filepath = dot.path.normalize(args.match)
      if yoz.path.is_descendant(dot.path.workspace(), filepath) then
        M.refresh()
      end
    end,
  })
end

return M
