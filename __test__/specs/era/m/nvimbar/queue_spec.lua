local harness = require("__test__.support.harness")
-- A controlled clock checks dispatch ordering without wall-clock timing assumptions.
local nvimbar = require("__test__.support.nvimbar")
local t = harness.new()

t:test("new work and deadline changes do not postpone an earlier task", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local seen = {}
  queue.add(function()
    seen[#seen + 1] = "first"
  end)
  clock:advance(0.5)
  queue.add(function()
    seen[#seen + 1] = "second"
  end)
  local key = {}
  queue.watch(key, 100, function()
    error("removed deadline")
  end)
  queue.unwatch(key)
  clock:advance(1)
  t.assert_same({ "first" }, seen)
  clock:advance(2)
  t.assert_same({ "first", "second" }, seen)
end)

t:test("pending main-loop dispatch is not duplicated by new work", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local calls = 0
  ---@return nil
  local function task()
    calls = calls + 1
  end
  queue.add(task)
  clock:advance(1, true)
  queue.add(task)
  clock:advance(2)
  t.assert_eq(1, calls, "one task in the first turn")
  clock:advance(3)
  t.assert_eq(2, calls, "the next task yields to another turn")
end)

t:test("deadlines expire while queued work continues", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local calls, expired = 0, 0
  for _ = 1, 3 do
    queue.add(function()
      calls = calls + 1
    end)
  end
  queue.watch({}, 2, function()
    expired = expired + 1
  end)
  clock:advance(1)
  t.assert_eq(0, expired)
  clock:advance(2)
  t.assert_eq(1, expired)
  t.assert_eq(2, calls)
  clock:advance(3)
  t.assert_eq(1, expired)
  t.assert_eq(3, calls)
end)

t:test("warm tasks share a turn within the time budget", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local calls = 0
  for _ = 1, 4 do
    queue.add(function()
      calls = calls + 1
      clock.now = clock.now + 0.6
    end, true)
  end
  clock:advance(1)
  t.assert_eq(2, calls, "the batch yields after its budget is spent")
  clock:advance(3.2)
  t.assert_eq(4, calls, "remaining tasks run in the next turn")
end)

t:test("cold tasks yield before and after their own turn", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local seen = {}
  queue.add(function()
    seen[#seen + 1] = "warm 1"
    vim.schedule(function()
      seen[#seen + 1] = "publish"
    end)
  end, true)
  queue.add(function()
    seen[#seen + 1] = "warm 2"
  end, true)
  queue.add(function()
    seen[#seen + 1] = "cold"
  end)
  queue.add(function()
    seen[#seen + 1] = "warm 3"
  end, true)
  clock:advance(1)
  t.assert_same({ "warm 1", "warm 2" }, seen)
  clock:advance(1.5)
  t.assert_eq("publish", seen[3], "ready data publishes before cold work")
  clock:advance(2)
  t.assert_eq("cold", seen[4])
  t.assert_eq(4, #seen, "cold work keeps its own turn")
  clock:advance(3)
  t.assert_eq("warm 3", seen[5])
end)

t:test("cancelled cold tasks do not delay the next live task", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local ran = false
  for _ = 1, 64 do
    local task = queue.add(function()
      error("cancelled work ran")
    end)
    queue.cancel(task)
  end
  queue.add(function()
    ran = true
  end)
  clock:advance(1)
  t.assert_true(ran, "discarded tasks do not consume 64 separate turns")
end)

t:test("disposed components release their cold queue entries before a live refresh", function()
  local clock = nvimbar.clock(t)
  local Component = clock.Component
  local context = { winnr = 1, bufnr = 1, tabnr = 1, cwd = "/test", filepath = "test.lua" }
  for _ = 1, 64 do
    local runtime = Component.new(function()
      error("disposed factory ran")
    end, function() end, function()
      return true
    end)
    runtime:request(context)
    runtime:dispose()
  end
  local live = Component.new({
    name = "live",
    refresh = function()
      return { text = "ready", hltext = "ready" }
    end,
  }, function() end, function()
    return true
  end)
  t:defer(function()
    live:dispose()
  end)
  live:request(context)
  clock:advance(1)
  t.assert_eq("ready", live.status)
end)

t:test("cancellation during dispatch does not split the remaining warm batch", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local removed
  local seen = {}
  queue.add(function()
    seen[#seen + 1] = "first"
    queue.cancel(removed)
  end, true)
  removed = queue.add(function()
    error("cancelled cold task ran")
  end)
  queue.add(function()
    seen[#seen + 1] = "last"
  end, true)
  clock:advance(1)
  t.assert_same({ "first", "last" }, seen)
end)

t:test("cancelling a task releases its closure before the queue drains", function()
  local queue = nvimbar.clock(t).queue
  local captured = {}
  local weak = setmetatable({ captured }, { __mode = "v" })
  local task = queue.add((function(value)
    return function()
      return value
    end
  end)(captured))
  captured = nil
  queue.cancel(task)
  collectgarbage("collect")
  t.assert_nil(weak[1])
  queue.cancel(task)
end)

t:test("a deadline is checked before the next warm batch", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local seen = {}
  for _ = 1, 3 do
    queue.add(function()
      seen[#seen + 1] = "task"
      clock.now = clock.now + 0.6
    end, true)
  end
  queue.watch({}, 1.5, function()
    seen[#seen + 1] = "expired"
  end)
  clock:advance(1)
  t.assert_eq(2, #seen)
  clock:advance(3.2)
  t.assert_same({ "task", "task", "expired", "task" }, seen)
end)

t:test("an expired callback can cancel and replace another due callback", function()
  local clock = nvimbar.clock(t)
  local queue = clock.queue
  local keys = { {}, {} }
  local expired, replacement = 0, 0
  for index = 1, 2 do
    queue.watch(keys[index], 10, function()
      expired = expired + 1
      local peer = keys[3 - index]
      queue.unwatch(peer)
      queue.watch(peer, 10, function()
        replacement = replacement + 1
      end)
    end)
  end
  clock:advance(10)
  t.assert_eq(1, expired, "cancelled callbacks do not run from the expiry snapshot")
  t.assert_eq(0, replacement)
  clock:advance(20)
  t.assert_eq(1, replacement)
end)

t:run()
