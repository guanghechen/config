--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/state_spec.lua
---@diagnostic disable: undefined-global
--- Test for era.m.git.state module

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")

local t = harness.new("era.m.git.state")
local workspace = "/project" ---@type string

local function normalize(filepath, keep_trailing_slash)
  local had_trailing_slash = filepath:sub(-1) == "/" or filepath:sub(-1) == "\\" ---@type boolean
  local normalized = filepath:gsub("\\", "/"):gsub("/+", "/") ---@type string
  if keep_trailing_slash == false and normalized ~= "/" then
    normalized = normalized:gsub("/+$", "")
  elseif keep_trailing_slash ~= false and had_trailing_slash and normalized:sub(-1) ~= "/" then
    normalized = normalized .. "/"
  end
  return normalized
end

local Observable = {}
local observable_next_counts = setmetatable({}, { __mode = "k" }) ---@type table<table, integer>

function Observable.from_value(initial)
  local value = initial ---@type any
  local observable ---@type table
  observable = {
    next = function(_, next_value)
      value = next_value
      observable_next_counts[observable] = observable_next_counts[observable] + 1
    end,
    snapshot = function()
      return value
    end,
  }
  observable_next_counts[observable] = 0
  return observable
end

local Future = {}
Future.__index = Future

function Future.new(executor)
  local self = setmetatable({ _done = false, _failed = false, _listeners = {} }, Future)
  executor(function(result)
    self._done = true
    self._result = result
    for _, listener in ipairs(self._listeners) do
      listener(true, result)
    end
  end, function(err)
    self._done = true
    self._failed = true
    self._error = err
    for _, listener in ipairs(self._listeners) do
      listener(false, err)
    end
  end)
  return self
end

function Future.resolve(result)
  return Future.new(function(resolve)
    resolve(result)
  end)
end

function Future.reject(err)
  return Future.new(function(_, reject)
    reject(err)
  end)
end

function Future:is_done()
  return self._done
end

function Future:is_failed()
  return self._failed
end

function Future:get_error()
  return self._error
end

function Future:finally(callback)
  if self._done then
    callback(not self._failed, self._failed and self._error or self._result)
  else
    self._listeners[#self._listeners + 1] = callback
  end
  return self
end

function Future:map(callback)
  return Future.new(function(resolve, reject)
    self:finally(function(ok, result)
      if not ok then
        reject(result)
        return
      end
      local callback_ok, value = pcall(callback, result)
      if callback_ok then
        resolve(value)
      else
        reject(value)
      end
    end)
  end)
end

---@param entries                       table<string, table>
---@return table
local function new_snapshot(entries)
  return {
    value = entries,
    equals = function(self, other)
      return vim.deep_equal(self.value, other.value)
    end,
    entries = function()
      return entries
    end,
    changed_files = function()
      return {}, vim.tbl_keys(entries)
    end,
    display = function()
      local result = {}
      for path, entry in pairs(entries) do
        result[path] = entry.display
      end
      return result
    end,
  }
end

bootstrap.with_runtime(t, {
  dot = {
    path = {
      dirname = function(filepath)
        local normalized = normalize(filepath, false)
        return normalized:match("^(.*)/[^/]+$") or normalized
      end,
      is_git_repo = function()
        return true
      end,
      join = function(from, to)
        return normalize(from .. "/" .. to, false)
      end,
      normalize = normalize,
      workspace = function()
        return workspace
      end,
    },
  },
  era = {
    m = {
      git = {
        status = {
          empty = function()
            return new_snapshot({})
          end,
        },
      },
    },
  },
  stl = {
    c = {
      CancellationToken = {
        new = function()
          local cancelled = false
          return {
            cancel = function()
              cancelled = true
            end,
            is_cancelled = function()
              return cancelled
            end,
          }
        end,
      },
      Future = Future,
      Observable = Observable,
    },
    env = {
      PATH_SEP = "/",
    },
    fn = {
      equals_deep = vim.deep_equal,
      noop = function() end,
    },
    reporter = {
      error = function() end,
      warn = function() end,
    },
    timer = {
      throttle = function(callback)
        return callback
      end,
    },
  },
})

local state = require("era.m.git.state")

---@param future table
local function wait_future(future)
  t.assert_true(
    vim.wait(3000, function()
      return future:is_done()
    end),
    "future should resolve"
  )
end

---@param observable table
---@return integer
local function next_count(observable)
  return observable_next_counts[observable]
end

t:test("refresh: successful collections publish without rebuilding unchanged status", function()
  local status_maps = {
    { ["/project/file"] = { display = "M" } },
    { ["/project/file"] = { display = "M" } },
    { ["/project/file"] = { display = "D" } },
  } ---@type table<string, table>[]
  ---@diagnostic disable-next-line: assign-type-mismatch
  local collect_index = 0 ---@type integer
  local collect_base = "unset" ---@type string|false

  t:patch_table(era.m.git.status, "collect", function(opts)
    collect_base = opts and opts.base or false
    collect_index = collect_index + 1
    return Future.new(function(resolve)
      resolve(new_snapshot(status_maps[collect_index]))
    end)
  end)

  local now = 0 ---@type integer
  t:patch_table(vim.uv, "now", function()
    now = now + 1
    return now
  end)

  local refreshed_before = next_count(state.o_refreshed)
  local staged_before = next_count(state.o_staged_files)
  local unstaged_before = next_count(state.o_unstaged_files)

  wait_future(state.refresh_index())
  t.assert_false(collect_base, "global refresh must support unborn HEAD")
  t.assert_eq(refreshed_before + 1, next_count(state.o_refreshed), "initial changed status notification")
  ---@diagnostic disable-next-line: undefined-field
  t.assert_eq("index", state.o_refreshed:snapshot().change_scope, "index-only refresh provenance")
  t.assert_eq(staged_before + 1, next_count(state.o_staged_files), "initial staged files notification")
  t.assert_eq(unstaged_before + 1, next_count(state.o_unstaged_files), "initial unstaged files notification")

  local snapshot = state.snapshot()

  wait_future(state.refresh(false))
  t.assert_eq(refreshed_before + 2, next_count(state.o_refreshed), "unchanged status notification")
  ---@diagnostic disable-next-line: undefined-field
  t.assert_eq("unknown", state.o_refreshed:snapshot().change_scope, "default refresh provenance")
  t.assert_eq(staged_before + 1, next_count(state.o_staged_files), "unchanged staged files notification")
  t.assert_eq(unstaged_before + 1, next_count(state.o_unstaged_files), "unchanged unstaged files notification")
  t.assert_true(state.snapshot() == snapshot, "unchanged status should preserve the native snapshot")
  t.assert_eq(2, state.last_refreshed_at(), "unchanged refresh should still update completion timestamp")

  wait_future(state.refresh(false))
  t.assert_eq(refreshed_before + 3, next_count(state.o_refreshed), "changed status notification")
  t.assert_eq(staged_before + 2, next_count(state.o_staged_files), "changed staged files notification")
  t.assert_eq(unstaged_before + 2, next_count(state.o_unstaged_files), "changed unstaged files notification")
  t.assert_true(state.snapshot() ~= snapshot, "changed status should replace the native snapshot")
  t.assert_eq("D", state.status_table()["/project/file"].display, "changed status should publish the new snapshot")
end)

t:test("refresh: failed collect reports once, preserves status, and permits recovery", function()
  local snapshot = state.snapshot()
  local refreshed_before = next_count(state.o_refreshed)
  local reports = {} ---@type table[]
  local attempts = 0 ---@type integer

  t:patch_table(era.m.git.status, "collect", function()
    attempts = attempts + 1
    if attempts == 1 then
      return Future.reject("fatal: status unavailable")
    end
    return Future.resolve(snapshot)
  end)
  t:patch_table(stl.reporter, "error", function(opts)
    reports[#reports + 1] = opts
  end)

  wait_future(state.refresh(false))
  t.assert_true(state.snapshot() == snapshot, "failed collect should preserve status cache")
  t.assert_eq(refreshed_before, next_count(state.o_refreshed), "failed collect notification")
  t.assert_eq(1, #reports, "failure reported once")
  t.assert_true(reports[1].message:find("fatal: status unavailable", 1, true) ~= nil, "failure reason preserved")

  wait_future(state.refresh(false))
  t.assert_eq(2, attempts, "later refresh retried")
  t.assert_eq(refreshed_before + 1, next_count(state.o_refreshed), "successful retry published")
  t.assert_eq(1, #reports, "successful retry emits no additional error")
end)

t:test("refresh: trailing provenance stays conservative", function()
  local resolvers = {} ---@type (fun(result: table): nil)[]
  t:patch_table(era.m.git.status, "collect", function()
    return Future.new(function(resolve)
      resolvers[#resolvers + 1] = resolve
    end)
  end)

  state.refresh_index()
  state.refresh(false)
  t.assert_eq(1, #resolvers, "index collection started")

  resolvers[1](new_snapshot({}))
  ---@diagnostic disable-next-line: undefined-field
  t.assert_eq("index", state.o_refreshed:snapshot().change_scope, "running collection keeps its provenance")
  t.assert_eq(2, #resolvers, "broader request starts a trailing collection")

  resolvers[2](new_snapshot({}))
  ---@diagnostic disable-next-line: undefined-field
  t.assert_eq("unknown", state.o_refreshed:snapshot().change_scope, "trailing collection stays conservative")
end)

t:test("status: propagates collection failures", function()
  t:patch_table(era.m.git.status, "collect", function()
    return Future.reject("fatal: status unavailable")
  end)

  local future = state.status("HEAD")

  t.assert_true(future:is_done(), "status future settled")
  t.assert_true(future:is_failed(), "status future rejected")
  t.assert_eq("fatal: status unavailable", future:get_error(), "collection error preserved")
end)

t:test("exit: queued refresh settles without starting another collection", function()
  t:patch_table(stl.timer, "throttle", require("stl.timer").throttle)
  local local_state = assert(loadfile("lua/era/m/git/state.lua"))()
  local_state.setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleGitState")
  end)
  local queries = 0
  t:patch_table(era.m.git.status, "collect", function()
    queries = queries + 1
    return Future.resolve(new_snapshot({}))
  end)

  local future = local_state.refresh()
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "DotModuleGitState" })
  local drained = false
  vim.schedule(function()
    drained = true
  end)
  t.wait_until(function()
    return drained
  end, 1000, "scheduled refresh callback did not drain")

  t.assert_true(future:is_done(), "queued caller settled during exit")
  t.assert_eq(0, queries, "already-scheduled refresh must not start after exit")
  t.assert_true(local_state.refresh():is_done(), "post-exit refresh settles immediately")
end)

t:test("exit: cancels inflight collection and suppresses late publication", function()
  t:patch_table(stl.timer, "throttle", require("stl.timer").throttle)
  local local_state = assert(loadfile("lua/era/m/git/state.lua"))()
  local_state.setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleGitState")
  end)
  local resolve, token
  t:patch_table(era.m.git.status, "collect", function(_, current_token)
    token = current_token
    return Future.new(function(callback)
      resolve = callback
    end)
  end)
  local future = local_state.refresh()
  t.wait_until(function()
    return resolve ~= nil
  end, 1000, "collection did not start")
  local before = local_state.snapshot()
  local refreshed_before = next_count(local_state.o_refreshed)

  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "DotModuleGitState" })
  t.assert_true(token:is_cancelled(), "inflight native token cancelled")
  resolve(new_snapshot({ ["/project/late"] = { display = "M" } }))

  t.assert_true(future:is_done(), "inflight caller settled")
  t.assert_true(local_state.snapshot() == before, "late result cannot replace snapshot")
  t.assert_eq(refreshed_before, next_count(local_state.o_refreshed), "no exit-time publication")
end)

t:run()
