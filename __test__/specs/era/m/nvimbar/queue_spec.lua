local harness = require("__test__.support.harness")
local t = harness.new("era.m.nvimbar.queue")

-- A controlled clock checks dispatch ordering without wall-clock timing assumptions.
local function clock()
  local now, due, callback = 0, nil, nil
  local scheduled = {}
  local shutdown
  local timer = {
    unref = function() end,
    start = function(_, delay, _, task)
      due, callback = now + delay, task
    end,
    stop = function()
      due = nil
    end,
    close = function() end,
  }
  t:patch_table(vim.uv, "new_timer", function()
    return timer
  end)
  t:patch_table(vim.uv, "hrtime", function()
    return now * 1e6
  end)
  t:patch_table(vim, "schedule", function(task)
    scheduled[#scheduled + 1] = task
  end)
  t:patch_table(vim.api, "nvim_create_autocmd", function(_, opts)
    shutdown = opts.callback
  end)
  local queue = assert(loadfile("lua/era/m/nvimbar/queue.lua"))()
  t:defer(function()
    shutdown()
  end)
  return queue,
    function(time, defer_dispatch)
      now = time
      if due and due <= now then
        due = nil
        callback()
      end
      if not defer_dispatch then
        local callbacks = scheduled
        scheduled = {}
        for _, task in ipairs(callbacks) do
          task()
        end
      end
    end,
    function(elapsed)
      now = now + elapsed
    end
end

t:test("new work and deadline changes do not postpone an earlier task", function()
  local queue, advance = clock()
  local seen = {}
  queue.add(function()
    seen[#seen + 1] = "first"
  end)
  advance(0.5)
  queue.add(function()
    seen[#seen + 1] = "second"
  end)
  local key = {}
  queue.watch(key, 100, function()
    error("removed deadline")
  end)
  queue.unwatch(key)
  advance(1)
  t.assert_true(vim.deep_equal({ "first" }, seen))
  advance(2)
  t.assert_true(vim.deep_equal({ "first", "second" }, seen))
end)

t:test("pending main-loop dispatch is not duplicated by new work", function()
  local queue, advance = clock()
  local calls = 0
  ---@return nil
  local function task()
    calls = calls + 1
  end
  queue.add(task)
  advance(1, true)
  queue.add(task)
  advance(2)
  t.assert_eq(1, calls, "one task in the first turn")
  advance(3)
  t.assert_eq(2, calls, "the next task yields to another turn")
end)

t:test("deadlines expire while queued work continues", function()
  local queue, advance = clock()
  local calls, expired = 0, 0
  for _ = 1, 3 do
    queue.add(function()
      calls = calls + 1
    end)
  end
  queue.watch({}, 2, function()
    expired = expired + 1
  end)
  advance(1)
  t.assert_eq(0, expired)
  advance(2)
  t.assert_eq(1, expired)
  t.assert_eq(2, calls)
  advance(3)
  t.assert_eq(1, expired)
  t.assert_eq(3, calls)
end)

t:test("warm tasks share a turn within the time budget", function()
  local queue, advance, consume = clock()
  local calls = 0
  for _ = 1, 4 do
    queue.add(function()
      calls = calls + 1
      consume(0.6)
    end, true)
  end
  advance(1)
  t.assert_eq(2, calls, "the batch yields after its budget is spent")
  advance(3.2)
  t.assert_eq(4, calls, "remaining tasks run in the next turn")
end)

t:test("cold tasks yield before and after their own turn", function()
  local queue, advance = clock()
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
  advance(1)
  t.assert_true(vim.deep_equal({ "warm 1", "warm 2" }, seen))
  advance(1.5)
  t.assert_eq("publish", seen[3], "ready data publishes before cold work")
  advance(2)
  t.assert_eq("cold", seen[4])
  t.assert_eq(4, #seen, "cold work keeps its own turn")
  advance(3)
  t.assert_eq("warm 3", seen[5])
end)

t:test("cancelled cold tasks do not delay the next live task", function()
  local queue, advance = clock()
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
  advance(1)
  t.assert_true(ran, "discarded tasks do not consume 64 separate turns")
end)

t:test("disposed components release their cold queue entries before a live refresh", function()
  local queue, advance = clock()
  t:patch_table(package.loaded, "era.m.nvimbar.queue", queue)
  local Component = assert(loadfile("lua/era/m/nvimbar/component.lua"))()
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
  advance(1)
  t.assert_eq("ready", live.status)
end)

t:test("cancellation during dispatch does not split the remaining warm batch", function()
  local queue, advance = clock()
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
  advance(1)
  t.assert_true(vim.deep_equal({ "first", "last" }, seen))
end)

t:test("cancelling a task releases its closure before the queue drains", function()
  local queue = clock()
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
  local queue, advance, consume = clock()
  local seen = {}
  for _ = 1, 3 do
    queue.add(function()
      seen[#seen + 1] = "task"
      consume(0.6)
    end, true)
  end
  queue.watch({}, 1.5, function()
    seen[#seen + 1] = "expired"
  end)
  advance(1)
  t.assert_eq(2, #seen)
  advance(3.2)
  t.assert_true(vim.deep_equal({ "task", "task", "expired", "task" }, seen))
end)

t:test("an expired callback can cancel and replace another due callback", function()
  local queue, advance = clock()
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
  advance(10)
  t.assert_eq(1, expired, "cancelled callbacks do not run from the expiry snapshot")
  t.assert_eq(0, replacement)
  advance(20)
  t.assert_eq(1, replacement)
end)

t:run()
