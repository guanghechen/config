---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_refresh_owner.lua

local harness = require("__test__.harness")
local async = require("stl.async")
local Future = require("stl.c.future")

local t = harness.new("era.m.diffview.workspace_refresh_owner")

local reported_errors = {} ---@type table[]
local CancellationToken = {}
CancellationToken.__index = CancellationToken

function CancellationToken.new()
  return setmetatable({ cancelled = false }, CancellationToken)
end

function CancellationToken:cancel()
  self.cancelled = true
end

function CancellationToken:is_cancelled()
  return self.cancelled
end

t:patch_global("stl", {
  async = async,
  c = { CancellationToken = CancellationToken, Future = Future },
  reporter = {
    error = function(opts)
      reported_errors[#reported_errors + 1] = opts
    end,
  },
})

local Refresh = assert(loadfile("lua/era/m/diffview/view/workspace/refresh.lua"))()

---@return era.m.diffview.view.workspace.Refresh owner
---@return table state
local function new_owner()
  local state = {
    completions = {},
    runs = 0,
    stale = false,
    tokens = {},
    valid = true,
    fail_runs = {},
  }
  local owner = Refresh.new({
    is_stale = function()
      return state.stale
    end,
    is_valid = function()
      return state.valid
    end,
    run = function(token)
      state.runs = state.runs + 1
      state.tokens[state.runs] = token
      local run = state.runs
      async.await(function(callback)
        state.completions[run] = callback
      end)
      if state.fail_runs[run] then
        error("deferred refresh failure")
      end
    end,
  })
  return owner, state
end

t:test("local requests collapse into one trailing refresh", function()
  local owner, state = new_owner()
  local callbacks = 0

  owner:request(function()
    callbacks = callbacks + 1
  end)
  owner:request()
  owner:request()

  t.assert_eq(1, state.runs, "running refresh")
  state.completions[1]()
  t.assert_eq(2, state.runs, "single trailing refresh")
  t.assert_eq(0, callbacks, "callback waits for trailing refresh")
  state.completions[2]()
  t.assert_eq(1, callbacks, "callback after refresh settles")
end)

t:test("local trailing refresh consumes an older watcher check", function()
  local owner, state = new_owner()

  owner:request()
  state.stale = true
  owner:request_if_stale()
  owner:request()

  state.completions[1]()
  t.assert_eq(2, state.runs, "single mixed trailing refresh")
  state.completions[2]()
  t.assert_eq(2, state.runs, "older watcher check consumed")
end)

t:test("watcher requests refresh only when entries remain stale", function()
  local owner, state = new_owner()

  owner:request()
  owner:request_if_stale()
  state.stale = false
  state.completions[1]()
  t.assert_eq(1, state.runs, "matching watcher event coalesced")

  state.stale = true
  owner:request_if_stale()
  t.assert_eq(2, state.runs, "stale watcher event refreshed")
  state.completions[2]()
end)

t:test("watcher refreshes stale peer views without repeating the originating view", function()
  local originating, originating_state = new_owner()
  local peer, peer_state = new_owner()

  originating:request()
  originating_state.stale = true
  originating:request_if_stale()

  peer_state.stale = true
  peer:request_if_stale()
  t.assert_eq(1, peer_state.runs, "stale peer refreshed")

  originating_state.stale = false
  originating_state.completions[1]()
  t.assert_eq(1, originating_state.runs, "matching origin coalesced")
  peer_state.completions[1]()
end)

t:test("deferred failure releases the owner", function()
  local owner, state = new_owner()
  local callbacks = 0
  state.fail_runs[1] = true

  owner:request(function()
    callbacks = callbacks + 1
  end)
  local ok, err = pcall(state.completions[1])
  t.assert_false(ok, "deferred failure propagated")
  t.assert_true(tostring(err):find("deferred refresh failure", 1, true) ~= nil, "failure preserved")
  t.assert_eq(0, callbacks, "failed refresh callback discarded")

  owner:request()
  t.assert_eq(2, state.runs, "owner accepts a later request")
  state.completions[2]()
end)

t:test("asynchronous rejection reports once, preserves state, and permits recovery", function()
  reported_errors = {}
  local published = "old"
  local runs = 0
  local futures = {} ---@type stl.c.Future[]
  local owner = Refresh.new({
    is_stale = function()
      return false
    end,
    is_valid = function()
      return true
    end,
    run = function()
      runs = runs + 1
      local future = Future.new()
      futures[runs] = future
      future:await()
      published = "new"
    end,
  })

  owner:request()
  futures[1]:__reject__("Git status staged diff failed") ---@diagnostic disable-line: invisible

  t.assert_eq("old", published, "failed refresh preserves state")
  t.assert_eq(1, #reported_errors, "failure reported once")
  t.assert_true(
    reported_errors[1].message:find("Git status staged diff failed", 1, true) ~= nil,
    "failure reason preserved"
  )

  owner:request()
  t.assert_eq(2, runs, "owner accepts a later request")
  futures[2]:__resolve__(nil) ---@diagnostic disable-line: invisible
  t.assert_eq("new", published, "later refresh succeeds")
  t.assert_eq(1, #reported_errors, "success emits no additional error")
end)

t:test("successful trailing refresh completes callbacks after an earlier failure", function()
  local owner, state = new_owner()
  local callbacks = 0
  state.fail_runs[1] = true

  owner:request(function()
    callbacks = callbacks + 1
  end)
  owner:request()

  local ok = pcall(state.completions[1])
  t.assert_false(ok, "earlier failure propagated")
  t.assert_eq(2, state.runs, "trailing refresh started")
  t.assert_eq(0, callbacks, "callback waits for trailing success")

  state.completions[2]()
  t.assert_eq(1, callbacks, "trailing success completes callback")
end)

t:test("dispose cancels owned resources and pending work", function()
  local owner, state = new_owner()

  owner:request()
  owner:request_if_stale()
  owner:dispose()

  t.assert_true(state.tokens[1].cancelled, "running refresh cancelled")
  state.completions[1]()
  owner:request()
  t.assert_eq(1, state.runs, "no refresh after dispose")
end)

t:test("status matching ignores order and diff statistics", function()
  local data = assert(loadfile("lua/era/m/diffview/data.lua"))()
  local status_map = {
    ["a.lua"] = {
      relative = "a.lua",
      stage = "staged",
      staged = { M = true },
      staged_old_object_name = "head-a",
      staged_new_object_name = "index-a",
    },
    ["b.lua"] = { relative = "b.lua", codes = { ["?"] = true }, unstaged = { ["?"] = true } },
  }
  local entries = {
    { filepath = "b.lua", stage_type = "unstaged", status = "?", insertions = 3 },
    {
      filepath = "a.lua",
      stage_type = "staged",
      status = "M",
      deletions = 2,
      old_object_name = "head-a",
      new_object_name = "index-a",
    },
  }

  t.assert_true(data.matches_status_entries(entries, status_map), "matching status entries")
  entries[1].status = "D"
  t.assert_false(data.matches_status_entries(entries, status_map), "changed status entry")
  entries[1].status = "?"
  entries[2].new_object_name = "index-b"
  t.assert_false(data.matches_status_entries(entries, status_map), "changed staged blob identity")

  local renamed = {
    ["new.lua"] = {
      relative = "new.lua",
      stage = "staged",
      staged = { R = true },
      staged_prev_relative = "old.lua",
    },
  }
  t.assert_false(
    data.matches_status_entries({ { filepath = "new.lua", stage_type = "staged", status = "R" } }, renamed),
    "changed rename source"
  )
end)

t:test("workspace coalesces index refreshes and forces broader refreshes", function()
  local subscriber = nil ---@type table|nil
  local ignore_initial = nil ---@type boolean|nil
  local forced_requests = 0 ---@type integer
  local stale_checks = 0 ---@type integer
  local state = {
    get_entries = function()
      return {}
    end,
    request_refresh = function()
      forced_requests = forced_requests + 1
    end,
    request_refresh_if_stale = function()
      stale_checks = stale_checks + 1
    end,
    set_git_subscription = function() end,
    set_refresh = function() end,
  }

  t:patch_table(stl.c, "Subscriber", {
    new = function(opts)
      return opts
    end,
  })
  t:patch_global("era", {
    m = {
      git = {
        state = {
          o_refreshed = {
            subscribe = function(_, value, ignored)
              subscriber = value
              ignore_initial = ignored
              return { unsubscribe = function() end }
            end,
          },
          o_staged_files = {
            subscribe = function()
              error("workspace must subscribe to o_refreshed")
            end,
          },
          status_table = function()
            return {}
          end,
        },
      },
    },
  })
  t:patch_table(package.loaded, "era.m.diffview.data", {
    matches_status_entries = function()
      return true
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.action", { refresh = function() end })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.refresh", {
    new = function()
      return {}
    end,
  })
  t:patch_table(package.loaded, "era.m.diffview.view.workspace.state", {
    get = function()
      return state
    end,
  })
  t:patch_table(vim.api, "nvim_tabpage_is_valid", function()
    return true
  end)

  local cmd = assert(loadfile("lua/era/m/diffview/cmd.lua"))()
  cmd.__setup_git_subscription_workspace__(state, { layout = { tabnr = 1 }, state = state })

  t.assert_true(subscriber ~= nil, "Git refresh subscriber")
  t.assert_true(ignore_initial, "initial generation ignored")
  assert(subscriber).on_next({ change_scope = "index", generation = 1 })
  t.assert_eq(1, stale_checks, "index refresh checks workspace snapshot")
  t.assert_eq(0, forced_requests, "index refresh is not forced")

  assert(subscriber).on_next({ change_scope = "unknown", generation = 2 })
  t.assert_eq(1, stale_checks, "broader refresh skips identity-only check")
  t.assert_eq(1, forced_requests, "broader refresh preserves worktree freshness")
end)

t:run()
