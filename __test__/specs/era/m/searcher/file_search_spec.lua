--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/searcher/file_search_spec.lua
---@diagnostic disable: invisible

local harness = require("__test__.support.harness")
local FileSearch = require("era.m.searcher.file_search")
local Scheduler = require("stl.c.scheduler")

local t = harness.new("era.m.searcher.file_search")

---@param id                            string
---@return era.m.searcher.file_search.IRequest
local function request(id)
  return { options = {}, context = { id = id } }
end

---@param polls                         table[]
---@return table
local function job(polls)
  local index = 0
  return {
    cancel_count = 0,
    dispose_count = 0,
    cancel = function(self)
      self.cancel_count = self.cancel_count + 1
    end,
    dispose = function(self)
      self.dispose_count = self.dispose_count + 1
    end,
    poll = function()
      index = math.min(index + 1, #polls)
      local value = polls[index]
      if value.throw ~= nil then
        error(value.throw)
      end
      return unpack(value)
    end,
  }
end

---@param props                         table
---@return era.m.searcher.FileSearch
---@return table
local function setup(props)
  local driver = { timers = {}, reports = {}, published = {} }
  local controller = FileSearch.new({
    name = "test",
    poll_interval = 1,
    is_current = props.is_current,
    start_job = props.start_job,
    set_interval = props.set_interval or function(callback)
      local timer = { callback = callback, closed = false }
      driver.timers[#driver.timers + 1] = timer
      return timer
    end,
    clear_timer = function(timer)
      timer.closed = true
    end,
    on_completed = props.on_completed or function(req, result)
      driver.published[#driver.published + 1] = { id = req.context.id, result = result }
    end,
    on_running = props.on_running,
    on_error = props.on_error or function(phase, err, req)
      driver.reports[#driver.reports + 1] = {
        phase = phase,
        error = err,
        id = req and req.context.id or nil,
      }
    end,
  })
  return controller, driver
end

local function tick(driver)
  local timer = driver.timers[#driver.timers]
  t.assert_true(timer ~= nil, "expected poll timer")
  timer.callback()
end

t:test("latest pending request replaces intermediate work", function()
  local jobs = {
    A = job({ { "completed", { items = { { p = "a" } } }, nil } }),
    C = job({ { "completed", { items = { { p = "c" } } }, nil } }),
  }
  local started = {}
  local controller, driver = setup({
    start_job = function(req)
      local id = req.context.id
      started[#started + 1] = id
      return jobs[id]
    end,
  })

  controller:invalidate()
  controller:submit(request("A"))
  controller:invalidate()
  controller:submit(request("B"))
  controller:invalidate()
  controller:submit(request("C"))

  tick(driver)
  t.assert_eq("A,C", table.concat(started, ","), "B must be replaced by C")
  t.assert_eq(0, #driver.published, "stale A must not publish")

  tick(driver)
  t.assert_eq(1, #driver.published, "C should publish")
  t.assert_eq("C", driver.published[1].id)
end)

t:test("invalidation suppresses completion before debounced submit", function()
  local jobs = {
    A = job({ { "completed", { items = {} }, nil } }),
    B = job({ { "completed", { items = {} }, nil } }),
  }
  local controller, driver = setup({
    start_job = function(req)
      return jobs[req.context.id]
    end,
  })

  controller:invalidate()
  controller:submit(request("A"))
  controller:invalidate()
  tick(driver)
  t.assert_eq(0, #driver.published, "A completion must be stale immediately")

  controller:submit(request("B"))
  tick(driver)
  t.assert_eq("B", driver.published[1].id)
end)

t:test("queued debounce task cannot submit after generation invalidation", function()
  local starts = 0
  local controller = setup({
    start_job = function()
      starts = starts + 1
      return job({ { "completed", { items = {} }, nil } })
    end,
  })
  ---@diagnostic disable-next-line: missing-fields -- Scheduler only needs next/snapshot from this test double.
  local scheduler_value = {
    next = function() end,
    snapshot = function()
      return true
    end,
  } --[[@as stl.c.Observable]]
  local scheduler = Scheduler.new({
    name = "test#debounce",
    mode = "debounce",
    delay = 10000,
    timeout = 0,
    silent = function()
      return false
    end,
    value = scheduler_value,
    task = function(_, context)
      local generation = context --[[@as integer]]
      if controller:is_current_generation(generation) then
        controller:submit(request(tostring(generation)))
      end
    end,
  })

  local queued_generation = controller:invalidate()
  scheduler:schedule({ immediate = true, context = queued_generation })
  local latest_generation = controller:invalidate()
  scheduler:schedule({ context = latest_generation })

  t.wait_until(function()
    return scheduler._tick_settled == 1
  end, 100, "queued debounce task should settle")
  local rescheduled_context = scheduler._context
  scheduler:dispose()
  controller:dispose()

  t.assert_eq(0, starts, "stale queued task must not start a search")
  t.assert_eq(latest_generation, rescheduled_context, "internal reschedule must preserve latest context")
end)

t:test("request freshness suppresses terminal work before generation invalidation", function()
  local current_id = "A"
  local jobs = {
    A = job({ { "completed", { items = {} }, nil } }),
    C = job({ { "failed", nil, "worker exploded" } }),
  }
  local controller, driver = setup({
    is_current = function(req)
      return req.context.id == current_id
    end,
    start_job = function(req)
      return jobs[req.context.id]
    end,
  })

  controller:invalidate()
  controller:submit(request("A"))
  current_id = "B"
  tick(driver)
  t.assert_eq(0, #driver.published, "stale completion must not publish before observer invalidation")

  current_id = "C"
  controller:submit(request("C"))
  current_id = "D"
  tick(driver)
  t.assert_eq(0, #driver.reports, "stale worker error must not report before observer invalidation")
end)

t:test("request freshness prevents a stale pending worker from starting", function()
  local current_id = "A"
  local jobs = {
    A = job({ { "completed", { items = {} }, nil } }),
    B = job({ { "completed", { items = {} }, nil } }),
  }
  local started = {}
  local controller, driver = setup({
    is_current = function(req)
      return req.context.id == current_id
    end,
    start_job = function(req)
      started[#started + 1] = req.context.id
      return jobs[req.context.id]
    end,
  })

  controller:invalidate()
  controller:submit(request("A"))
  current_id = "B"
  controller:invalidate()
  controller:submit(request("B"))
  current_id = "C"
  tick(driver)

  t.assert_eq("A", table.concat(started, ","), "stale pending B must not start for current inputs C")
end)

t:test("poll failure detaches active and advances current pending", function()
  local jobs = {
    A = job({ { throw = "poll exploded" } }),
    B = job({ { "completed", { items = {} }, nil } }),
  }
  local started = {}
  local controller, driver = setup({
    start_job = function(req)
      local id = req.context.id
      started[#started + 1] = id
      return jobs[id]
    end,
  })

  controller:invalidate()
  controller:submit(request("A"))
  controller:invalidate()
  controller:submit(request("B"))
  tick(driver)

  t.assert_eq("A,B", table.concat(started, ","))
  t.assert_eq(0, #driver.reports, "stale poll failure must be suppressed")
  t.assert_eq(1, jobs.A.dispose_count, "failed active job must be disposed once")

  tick(driver)
  t.assert_eq("B", driver.published[1].id)
end)

t:test("start and timer failures report once without stranding work", function()
  local start_controller, start_driver = setup({
    start_job = function()
      error("spawn failed")
    end,
  })
  start_controller:invalidate()
  start_controller:submit(request("start"))
  t.assert_eq(1, #start_driver.reports)
  t.assert_eq("start", start_driver.reports[1].phase)

  local starts = 0
  local timer_controller, timer_driver = setup({
    start_job = function()
      starts = starts + 1
      return job({ { "running", nil, nil } })
    end,
    set_interval = function()
      return nil
    end,
  })
  timer_controller:invalidate()
  timer_controller:submit(request("timer"))
  t.assert_eq(0, starts, "worker must not start without a poll driver")
  t.assert_eq(1, #timer_driver.reports)
  t.assert_eq("timer", timer_driver.reports[1].phase)
end)

t:test("publish failure is caught after cleanup", function()
  local next_job = job({ { "completed", { items = {} }, nil } })
  local starts = 0
  local controller, driver = setup({
    start_job = function()
      starts = starts + 1
      return next_job
    end,
    on_completed = function()
      error("apply failed")
    end,
  })

  controller:invalidate()
  controller:submit(request("A"))
  tick(driver)
  t.assert_eq(1, #driver.reports)
  t.assert_eq("publish", driver.reports[1].phase)

  controller:invalidate()
  controller:submit(request("B"))
  t.assert_eq(2, starts, "publish error must not strand active identity")
end)

t:test("running observer failure is isolated and reported once", function()
  local active_job = job({
    { "running", nil, nil },
    { "running", nil, nil },
    { "completed", { items = {} }, nil },
  })
  local running_calls = 0
  local controller, driver = setup({
    start_job = function()
      return active_job
    end,
    on_running = function()
      running_calls = running_calls + 1
      error("spinner failed")
    end,
  })

  controller:invalidate()
  controller:submit(request("A"))
  tick(driver)
  tick(driver)
  tick(driver)

  t.assert_eq(1, running_calls, "failed observer must be disabled")
  t.assert_eq(1, #driver.reports, "observer failure must report once")
  t.assert_eq("progress", driver.reports[1].phase)
  t.assert_eq(1, #driver.published, "observer failure must not strand the worker")
end)

t:test("dispose invalidates an already queued timer callback", function()
  local active_job = job({ { "completed", { items = {} }, nil } })
  local controller, driver = setup({
    start_job = function()
      return active_job
    end,
  })
  controller:invalidate()
  controller:submit(request("A"))

  local callback = driver.timers[1].callback
  controller:dispose()
  callback()

  t.assert_eq(0, #driver.published)
  t.assert_eq(0, #driver.reports)
  t.assert_eq(1, active_job.dispose_count)
  t.assert_true(driver.timers[1].closed)
end)

t:run()
