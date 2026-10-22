local harness = require("__test__.support.harness")
require("ark.bootstrap").setup()

local t = harness.new()
local Git = require("era.m.git.state")

---A status snapshot as State uses it: compared with `equals`, read through `entries`.
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
  }
end

---@class __test__.git.state.IQuery
---@field public token                  stl.c.CancellationToken
---@field public started                integer
---@field public resolve                fun(snapshot: table): nil
---@field public reject                 fun(err: string): nil

---A State whose collections wait until the test settles them.
---@param throttle_ms                   ?integer
---@return era.m.git.State
---@return __test__.git.state.IQuery[]
local function new_state(throttle_ms)
  local queries = {} ---@type __test__.git.state.IQuery[]
  local state = Git.State.new({
    collect = function(token)
      local query = { token = token, started = vim.uv.hrtime() } ---@type __test__.git.state.IQuery
      queries[#queries + 1] = query
      return stl.c.Future.new(function(resolve, reject)
        query.resolve, query.reject = resolve, reject
      end)
    end,
    snapshot = new_snapshot({}),
    throttle_ms = throttle_ms or 20,
  })
  t:defer(function()
    state:dispose()
  end)
  return state, queries
end

---@param queries                       __test__.git.state.IQuery[]
---@param count                         integer
---@param message                       string
---@return nil
local function await_queries(queries, count, message)
  t.wait_until(function()
    return #queries >= count
  end, 2000, message)
  t.assert_eq(count, #queries, message)
end

---@param future                        stl.c.Future
---@return nil
local function wait_future(future)
  t.wait_until(function()
    return future:is_done()
  end, 3000, "future should resolve")
end

-- Each publication advances the generation; subscribers hear of it on a later tick.
---@param state                         era.m.git.State
---@return integer
local function publications(state)
  return state.o_refreshed:snapshot().generation
end

t:test("refresh: successful collections publish without rebuilding unchanged status", function()
  local state, queries = new_state()

  local first = state:refresh_index()
  await_queries(queries, 1, "index collection")
  queries[1].resolve(new_snapshot({ ["/project/file"] = { display = "M" } }))
  wait_future(first)
  t.assert_eq(1, publications(state), "initial changed status notification")
  t.assert_eq("index", state.o_refreshed:snapshot().change_scope, "index-only refresh provenance")

  local snapshot = state:snapshot()

  local second = state:refresh()
  await_queries(queries, 2, "unchanged collection")
  queries[2].resolve(new_snapshot({ ["/project/file"] = { display = "M" } }))
  wait_future(second)
  t.assert_eq(2, publications(state), "unchanged status notification")
  t.assert_eq("unknown", state.o_refreshed:snapshot().change_scope, "default refresh provenance")
  t.assert_true(state:snapshot() == snapshot, "unchanged status should preserve the native snapshot")

  local third = state:refresh()
  await_queries(queries, 3, "changed collection")
  queries[3].resolve(new_snapshot({ ["/project/file"] = { display = "D" } }))
  wait_future(third)
  t.assert_eq(3, publications(state), "changed status notification")
  t.assert_true(state:snapshot() ~= snapshot, "changed status should replace the native snapshot")
  t.assert_eq(
    "D",
    state:snapshot():entries()["/project/file"].display,
    "changed status should publish the new snapshot"
  )
end)

t:test("refresh: failed collect reports once, preserves status, and permits recovery", function()
  local state, queries = new_state()
  local snapshot = state:snapshot()
  local reports = {} ---@type table[]
  t:patch_table(stl.reporter, "error", function(opts)
    reports[#reports + 1] = opts
  end)

  local first = state:refresh()
  await_queries(queries, 1, "failing collection")
  queries[1].reject("fatal: status unavailable")
  wait_future(first)
  t.assert_true(state:snapshot() == snapshot, "failed collect should preserve status cache")
  t.assert_eq(0, publications(state), "failed collect notification")
  t.assert_eq(1, #reports, "failure reported once")
  t.assert_true(reports[1].message:find("fatal: status unavailable", 1, true) ~= nil, "failure reason preserved")

  local second = state:refresh()
  await_queries(queries, 2, "later refresh retried")
  queries[2].resolve(snapshot)
  wait_future(second)
  t.assert_eq(1, publications(state), "successful retry published")
  t.assert_eq(1, #reports, "successful retry emits no additional error")
end)

t:test("refresh: trailing provenance stays conservative", function()
  local state, queries = new_state()

  state:refresh_index()
  await_queries(queries, 1, "index collection started")
  state:refresh()

  queries[1].resolve(new_snapshot({}))
  t.assert_eq("index", state.o_refreshed:snapshot().change_scope, "running collection keeps its provenance")
  await_queries(queries, 2, "broader request starts a trailing collection")

  queries[2].resolve(new_snapshot({}))
  t.assert_eq("unknown", state.o_refreshed:snapshot().change_scope, "trailing collection stays conservative")
end)

t:test("refresh: callers arriving during a query wait for the trailing snapshot", function()
  local state, queries = new_state()

  local first = state:refresh_index()
  await_queries(queries, 1, "first collection started")
  local second = state:refresh()
  local third = state:refresh_index()
  queries[1].resolve(new_snapshot({ ["/project/old"] = { display = "M" } }))

  t.assert_true(first:is_done(), "first caller completes with its query")
  t.assert_false(second:is_done(), "a caller arriving during the query waits for the newer query")
  t.assert_false(third:is_done(), "coalesced caller also waits")
  await_queries(queries, 2, "requests coalesce into one trailing query")

  queries[2].resolve(new_snapshot({ ["/project/new"] = { display = "M" } }))
  t.assert_true(second:is_done(), "trailing caller completes")
  t.assert_true(third:is_done(), "coalesced refresh completes")
  t.assert_true(state:snapshot():entries()["/project/new"] ~= nil, "new snapshot is published first")
  t.assert_eq("unknown", state.o_refreshed:snapshot().change_scope, "mixed provenance stays conservative")
end)

t:test("refresh: a failed query does not complete callers waiting for its successor", function()
  local state, queries = new_state()
  t:patch_table(stl.reporter, "error", function() end)

  local first = state:refresh()
  await_queries(queries, 1, "first collection started")
  local second = state:refresh()
  queries[1].reject("query failed")
  t.assert_true(first:is_done(), "failed collection retains the existing settlement contract")
  t.assert_false(second:is_done(), "later caller remains pending")
  await_queries(queries, 2, "trailing collection starts after failure")
  queries[2].resolve(new_snapshot({}))
  t.assert_true(second:is_done(), "later caller settles with the successful retry")
end)

t:test("refresh: requests made while callers settle wait for a newer snapshot", function()
  local state, queries = new_state()
  local trailing ---@type stl.c.Future|nil
  state:refresh():finally(function()
    trailing = state:refresh()
  end)

  await_queries(queries, 1, "first collection started")
  queries[1].resolve(new_snapshot({}))
  assert(trailing ~= nil, "the settled caller requested a refresh")
  t.assert_false(trailing:is_done(), "a settling caller cannot complete its own refresh request")
  await_queries(queries, 2, "the request starts a newer collection")
  queries[2].resolve(new_snapshot({}))
  t.assert_true(trailing:is_done(), "the request completes after its query")
end)

t:test("refresh: the throttle coalesces callers before and during a query", function()
  local state, queries = new_state()

  local first = state:refresh_index()
  local joined = state:refresh_index()
  await_queries(queries, 1, "initial requests should share a query")
  local trailing = state:refresh()
  queries[1].resolve(new_snapshot({}))
  t.assert_true(first:is_done(), "first query completed")
  t.assert_true(joined:is_done(), "pre-query caller joined the first collection")
  t.assert_false(trailing:is_done(), "inflight caller waits")

  await_queries(queries, 2, "trailing query should start after the throttle interval")
  queries[2].resolve(new_snapshot({}))
  t.assert_true(trailing:is_done(), "inflight caller settles after the newer collection")
  t.assert_eq("unknown", state.o_refreshed:snapshot().change_scope, "saved-file provenance retained")
end)

t:test("dispose: a queued refresh settles without starting another collection", function()
  local state, queries = new_state()

  local future = state:refresh()
  state:dispose()
  local drained = false
  vim.schedule(function()
    drained = true
  end)
  t.wait_until(function()
    return drained
  end, 1000, "scheduled refresh callback did not drain")

  t.assert_true(future:is_done(), "queued caller settled during exit")
  t.assert_eq(0, #queries, "already-scheduled refresh must not start after exit")
  t.assert_true(state:refresh():is_done(), "post-exit refresh settles immediately")
end)

t:test("dispose: cancels inflight collection and suppresses late publication", function()
  local state, queries = new_state()

  local future = state:refresh()
  await_queries(queries, 1, "collection did not start")
  local before = state:snapshot()
  local trailing = state:refresh()
  local completed = 0
  future:finally(function()
    completed = completed + 1
  end)
  trailing:finally(function()
    completed = completed + 1
  end)

  state:dispose()
  t.assert_true(queries[1].token:is_cancelled(), "inflight native token cancelled")
  t.assert_true(future:is_done(), "inflight caller settles before native acknowledgement")
  t.assert_true(trailing:is_done(), "queued caller settles on exit")
  t.assert_eq(2, completed, "both generations settled")
  queries[1].resolve(new_snapshot({ ["/project/late"] = { display = "M" } }))

  t.assert_eq(2, completed, "native acknowledgement cannot settle callers twice")
  t.assert_true(future:is_done(), "inflight caller settled")
  t.assert_true(state:snapshot() == before, "late result cannot replace snapshot")
  t.assert_eq(0, publications(state), "no exit-time publication")
end)

t:test("default: collections pass no base, so an unborn HEAD still has a status", function()
  local calls = {} ---@type { opts: table|nil }[]
  t:patch_table(era.m.git.status, "collect", function(opts)
    calls[#calls + 1] = { opts = opts }
    return stl.c.Future.resolve(era.m.git.status.empty())
  end)

  wait_future(Git.refresh())
  t.assert_eq(1, #calls, "one collection")
  t.assert_nil(calls[1].opts, "global refresh must support unborn HEAD")
end)

t:test("writes: refresh repository files without requiring a Git buffer attachment", function()
  t:patch_table(dot.path, "workspace", function()
    return "/project"
  end)
  local in_repo = true
  t:patch_table(dot.path, "is_git_repo", function()
    return in_repo
  end)
  Git.setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleGitState")
  end)
  local requests = 0
  t:patch_table(Git, "refresh", function()
    requests = requests + 1
  end)

  for _, case in ipairs({
    { path = "/project/tracked.lua", expected = 1 },
    { path = "/project/new.lua", expected = 2 },
    { path = "/project/nested/file.lua", expected = 3 },
    { path = "/project-other/file.lua", expected = 3 },
    { path = "/outside/file.lua", expected = 3 },
    { path = "/project/scratch", buftype = "nofile", expected = 3 },
    { path = "/outside/source.lua", target = "/project/written.lua", expected = 4 },
    { path = "/project/source.lua", target = "/outside/written.lua", expected = 4 },
  }) do
    local bufnr = vim.api.nvim_create_buf(false, true)
    t:defer(function()
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
    vim.api.nvim_buf_set_name(bufnr, case.path)
    vim.api.nvim_set_option_value("buftype", case.buftype or "", { buf = bufnr })
    vim.api.nvim_buf_call(bufnr, function()
      vim.api.nvim_exec_autocmds("BufWritePost", {
        group = "DotModuleGitState",
        pattern = case.target or case.path,
      })
    end)
    t.assert_eq(case.expected, requests, case.path)
  end

  in_repo = false
  vim.api.nvim_exec_autocmds("BufWritePost", { group = "DotModuleGitState", pattern = "/project/file.lua" })
  t.assert_eq(4, requests, "non-repository workspace does not refresh")
end)

-- Exit disposes the shared state for the rest of this process, so this case runs last.
t:test("setup: exit disposes the shared state", function()
  t:patch_table(era.m.git.status, "collect", function()
    return stl.c.Future.new(function() end)
  end)
  Git.setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleGitState")
  end)

  local future = Git.refresh()
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "DotModuleGitState" })
  t.assert_true(future:is_done(), "exit settles waiting callers")
  t.assert_true(Git.refresh():is_done(), "post-exit refresh settles immediately")
end)

t:test("refresh: collections are spaced by four times the last one's duration, from 100 ms to the limit", function()
  local state, queries = new_state(800)
  ---@param count                       integer
  ---@param hold_ms                     integer
  ---@return nil
  local function collect(count, hold_ms)
    local future = state:refresh()
    await_queries(queries, count, "collection " .. count)
    if hold_ms > 0 then
      vim.wait(hold_ms)
    end
    queries[count].resolve(new_snapshot({}))
    wait_future(future)
  end
  ---@param count                       integer
  ---@return number
  local function spacing(count)
    return (queries[count].started - queries[count - 1].started) / 1e6
  end

  collect(1, 0)
  collect(2, 60)
  t.assert_true(
    spacing(2) >= 90 and spacing(2) < 500,
    string.format("a quick query holds the next for 100 ms: %.1f", spacing(2))
  )
  collect(3, 0)
  collect(4, 0)
  t.assert_true(spacing(4) >= 230, string.format("a 60 ms query holds the one after it for 240 ms: %.1f", spacing(4)))
end)

t:run()
