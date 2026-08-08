---@diagnostic disable: undefined-global
--- Run with: nvim -l lua/__test__/era/m/diffview/workspace_refresh_owner.lua

local harness = require("__test__.harness")
local async = require("stl.async")

local t = harness.new("era.m.diffview.workspace_refresh_owner")

local timers = {} ---@type table[]
local CancellationToken = {}
CancellationToken.__index = CancellationToken

function CancellationToken.new()
  return setmetatable({ cancelled = false }, CancellationToken)
end

function CancellationToken:cancel()
  self.cancelled = true
end

t:patch_global("stl", {
  async = async,
  c = { CancellationToken = CancellationToken },
  timer = {
    debounce = function(callback)
      local timer = { disposed = false, pending = false }
      function timer:dispose()
        self.disposed = true
        self.pending = false
      end
      function timer:fire()
        if self.pending and not self.disposed then
          self.pending = false
          callback()
        end
      end
      timers[#timers + 1] = setmetatable(timer, {
        __call = function(self)
          if not self.disposed then
            self.pending = true
          end
        end,
      })
      return timers[#timers]
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
    debounce_ms = 300,
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
  state.timer = timers[#timers]
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
  state.timer:fire()
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
  state.timer:fire()
  state.stale = false
  state.completions[1]()
  t.assert_eq(1, state.runs, "matching watcher event coalesced")

  state.stale = true
  owner:request_if_stale()
  state.timer:fire()
  t.assert_eq(2, state.runs, "stale watcher event refreshed")
  state.completions[2]()
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
  t.assert_true(state.timer.disposed, "debounce disposed")
  state.completions[1]()
  state.timer:fire()
  owner:request()
  t.assert_eq(1, state.runs, "no refresh after dispose")
end)

t:test("status matching ignores order and diff statistics", function()
  local data = assert(loadfile("lua/era/m/diffview/data.lua"))()
  local status_map = {
    ["a.lua"] = { relative = "a.lua", stage = "staged", staged = { M = true } },
    ["b.lua"] = { relative = "b.lua", codes = { ["?"] = true } },
  }
  local entries = {
    { filepath = "b.lua", stage_type = "unstaged", status = "?", insertions = 3 },
    { filepath = "a.lua", stage_type = "staged", status = "M", deletions = 2 },
  }

  t.assert_true(data.matches_status_entries(entries, status_map), "matching status entries")
  entries[1].status = "D"
  t.assert_false(data.matches_status_entries(entries, status_map), "changed status entry")
end)

t:run()
