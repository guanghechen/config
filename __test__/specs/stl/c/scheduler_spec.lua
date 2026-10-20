local harness = require("__test__.support.harness")

local t = harness.new()

t:patch_global("stl", {
  fn = {
    falsy = function()
      return false
    end,
  },
  reporter = { error = function() end },
})

---@class stl.c.scheduler.test.ITimer
---@field callback                      ?fun()
---@field active                        boolean

---@class stl.c.scheduler.test.IRuntime
---@field scheduler                     stl.c.Scheduler
---@field window                        stl.c.scheduler.test.ITimer
---@field scheduled                     fun()[]
---@field runs                          integer
---@field settle                        ?fun()

---@param async                         boolean
---@return stl.c.scheduler.test.IRuntime
local function setup(async)
  local timers = {} ---@type stl.c.scheduler.test.ITimer[]
  t:patch_table(vim.uv, "new_timer", function()
    local timer = { active = false } ---@type stl.c.scheduler.test.ITimer
    function timer:start(_, _, callback)
      self.active = true
      self.callback = callback
    end
    function timer:stop()
      self.active = false
    end
    function timer:close() end
    timers[#timers + 1] = timer
    return timer
  end)
  local runtime = { scheduled = {}, runs = 0 } ---@type stl.c.scheduler.test.IRuntime
  t:patch_table(vim, "schedule", function(callback)
    runtime.scheduled[#runtime.scheduled + 1] = callback
  end)
  t:patch_table(vim, "schedule_wrap", function(callback)
    return function(...)
      local args = { ... }
      runtime.scheduled[#runtime.scheduled + 1] = function()
        callback(unpack(args))
      end
    end
  end)

  local Scheduler = assert(loadfile("lua/stl/c/scheduler.lua"))()
  runtime.scheduler = Scheduler.new({
    name = "spec",
    mode = "throttle",
    delay = 128,
    timeout = async and 10000 or 0,
    value = { next = function() end },
    task = function(_, _, callback)
      runtime.runs = runtime.runs + 1
      if async then
        runtime.settle = function()
          callback(true, runtime.runs)
        end
        return nil
      end
      return runtime.runs
    end,
  })
  runtime.window = timers[1]
  return runtime
end

---@param runtime                       stl.c.scheduler.test.IRuntime
---@return nil
local function drain(runtime)
  while #runtime.scheduled > 0 do
    table.remove(runtime.scheduled, 1)()
  end
end

---@param runtime                       stl.c.scheduler.test.IRuntime
---@return nil
local function close_window(runtime)
  runtime.window.active = false
  assert(runtime.window.callback)()
  drain(runtime)
end

t:test("throttle runs the first call at once and merges calls within the window", function()
  local runtime = setup(false)
  runtime.scheduler:schedule()
  drain(runtime)
  t.assert_eq(1, runtime.runs, "leading run")

  runtime.scheduler:schedule()
  runtime.scheduler:schedule()
  drain(runtime)
  t.assert_eq(1, runtime.runs, "runs within the window")

  close_window(runtime)
  t.assert_eq(2, runtime.runs, "trailing run")
end)

t:test("an idle window does not restart the throttle timer", function()
  local runtime = setup(false)
  runtime.scheduler:schedule()
  drain(runtime)

  close_window(runtime)
  t.assert_false(runtime.window.active, "timer after an idle window")
  t.assert_eq(1, runtime.runs, "runs after an idle window")

  runtime.scheduler:schedule()
  drain(runtime)
  t.assert_eq(2, runtime.runs, "next call runs at once")
end)

t:test("a run outliving the window merges calls into one run when it settles", function()
  local runtime = setup(true)
  runtime.scheduler:schedule()
  drain(runtime)
  runtime.scheduler:schedule()
  runtime.scheduler:schedule()

  close_window(runtime)
  t.assert_eq(1, runtime.runs, "runs while the first is in flight")

  assert(runtime.settle)()
  drain(runtime)
  t.assert_eq(2, runtime.runs, "trailing run after settling")
end)

t:test("an immediate call runs at once", function()
  local runtime = setup(false)
  runtime.scheduler:schedule()
  drain(runtime)
  runtime.scheduler:schedule({ immediate = true })
  drain(runtime)
  t.assert_eq(2, runtime.runs, "immediate run")

  close_window(runtime)
  t.assert_false(runtime.window.active, "timer after the immediate window")
end)

t:run()
