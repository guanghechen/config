local git_buffer = require("__test__.support.git_buffer")
local harness = require("__test__.support.harness")
local t = harness.new()
git_buffer.with_futures(t)
local jobs = require("era.m.job")

---A native job that runs until the case sets its `state`, and the start function that returns it.
---@return table job
---@return fun(): table start
local function new_job()
  local job = { state = "running", started = 0, disposed = 0, cancelled = 0, snapshot = {} }
  ---@return string
  ---@return table
  ---@return string|nil
  function job:poll()
    return self.state, self.snapshot, self.err
  end
  ---@return nil
  function job:cancel()
    self.cancelled = self.cancelled + 1
    self.state = "cancelled"
  end
  ---@return nil
  function job:dispose()
    self.disposed = self.disposed + 1
  end
  return job, function()
    job.started = job.started + 1
    return job
  end
end

t:test("cancellation waits for worker acknowledgement and suppresses completed data", function()
  local job, start = new_job()
  local token = stl.c.CancellationToken.new()
  local future = jobs.run(start, token)
  token:cancel()
  job.state = "completed"
  t.settle(future)
  t.assert_eq(1, job.cancelled, "native cancel requested")
  t.assert_true(future:is_failed(), "stale completion rejected")
  t.assert_eq("Operation cancelled", future:get_error(), "cancellation result")
  t.assert_eq(1, job.disposed, "cancelled job disposed")
end)

t:test("worker errors and poll failures reject once and release resources", function()
  for _, throws in ipairs({ false, true }) do
    local job, start = new_job()
    job.state = "failed"
    job.err = "Git query failed"
    if throws then
      job.poll = function()
        error("poll failed")
      end
    end
    local future = jobs.run(start)
    t.settle(future)
    t.assert_true(future:is_failed(), "failure propagated")
    t.assert_eq(1, job.disposed, "failed job disposed")
  end
end)

t:test("start failures and missing timers reject without leaving a running job", function()
  local future = jobs.run(function()
    error("spawn failed")
  end)
  t.assert_true(future:is_failed(), "start failure")
  local job, start = new_job()
  t:patch_table(vim.uv, "new_timer", function()
    return nil
  end)
  future = jobs.run(start)
  t.assert_true(future:is_failed(), "timer failure")
  t.assert_eq(0, job.started, "no native job started without a poll timer")
end)

t:test("poll scheduling coalesces while the editor is busy", function()
  local job, start = new_job()
  local queued = {}
  t:patch_table(vim, "schedule", function(callback)
    queued[#queued + 1] = callback
  end)
  local future = jobs.run(start)
  t.wait_until(function()
    return #queued > 0
  end, 5000, "the poll timer must queue a poll callback")
  -- Later timer ticks within this window must coalesce into the queued callback.
  vim.wait(30, function()
    return false
  end, 1)
  t.assert_eq(1, #queued, "one pending poll callback")
  job.state = "completed"
  queued[1]()
  t.assert_true(future:is_done(), "queued poll publishes")
end)

-- Exit leaves era.m.job rejecting every later run in this process, so this case must stay last.
t:test("exit cancels active jobs and prevents new work", function()
  local job, start = new_job()
  jobs.setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleNativeJobs")
  end)
  local future = jobs.run(start)
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "DotModuleNativeJobs" })
  t.assert_true(future:is_done(), "exit settled active Future")
  t.assert_true(future:is_failed(), "exit does not publish")
  t.assert_eq(1, job.disposed, "exit disposed native job")
  local later, start_later = new_job()
  t.assert_true(jobs.run(start_later):is_failed(), "no query after exit")
  t.assert_eq(0, later.started, "no native job started after exit")
end)

t:run()
