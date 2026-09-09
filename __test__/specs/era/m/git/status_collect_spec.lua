--- Run with: nvim -l __test__/run.lua __test__/specs/era/m/git/status_collect_spec.lua
---@diagnostic disable: undefined-global

local bootstrap = require("__test__.support.bootstrap")
local harness = require("__test__.support.harness")
local t = harness.new("era.m.git.status adapter")
bootstrap.with_stl_c(t)
bootstrap.with_runtime(t, {
  dot = {
    path = {
      workspace = function()
        return "/repo"
      end,
      is_git_repo = function()
        return true
      end,
    },
  },
  yoz = { git = {
    empty_status = function()
      return {}
    end,
  } },
})

---@return era.m.git.status
local function new_status()
  return assert(loadfile("lua/era/m/git/status.lua"))()
end

---@return table
local function new_job()
  local job = { state = "running", disposed = 0, cancelled = 0, snapshot = {} }
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
  t:patch_table(yoz.git, "start_status", function(options)
    job.options = options
    return job
  end)
  return job
end

---@param future                        stl.c.Future
---@return nil
local function wait(future)
  t.wait_until(function()
    return future:is_done()
  end, 3000, "adapter Future did not settle")
end

t:test("native snapshot is published without materializing its entries", function()
  local job = new_job()
  local future = new_status().collect({ base = "HEAD", include_numstat = true, include_untracked = false })
  t.assert_false(future:is_done(), "running job")
  t.assert_eq("/repo", job.options.cwd, "workspace captured")
  t.assert_false(job.options.include_untracked, "untracked exclusion")
  t.assert_true(job.options.include_numstat, "numstat request")
  t.assert_eq("HEAD", job.options.base, "base")
  job.state = "completed"
  wait(future)
  t.assert_true(future:get_result() == job.snapshot, "native handle passed through")
  t.assert_eq(1, job.disposed, "completed job disposed")
end)

t:test("cancellation waits for worker acknowledgement and suppresses completed data", function()
  local job = new_job()
  local token = stl.c.CancellationToken.new()
  local future = new_status().collect(nil, token)
  token:cancel()
  job.state = "completed"
  wait(future)
  t.assert_eq(1, job.cancelled, "native cancel requested")
  t.assert_true(future:is_failed(), "stale completion rejected")
  t.assert_eq("Operation cancelled", future:get_error(), "cancellation result")
  t.assert_eq(1, job.disposed, "cancelled job disposed")
end)

t:test("worker errors and poll failures reject once and release resources", function()
  for _, throws in ipairs({ false, true }) do
    local job = new_job()
    job.state = "failed"
    job.err = "Git query failed"
    if throws then
      job.poll = function()
        error("poll failed")
      end
    end
    local future = new_status().collect()
    wait(future)
    t.assert_true(future:is_failed(), "failure propagated")
    t.assert_eq(1, job.disposed, "failed job disposed")
  end
end)

t:test("start failures and missing timers reject without leaving a running job", function()
  t:patch_table(yoz.git, "start_status", function()
    error("spawn failed")
  end)
  local future = new_status().collect()
  t.assert_true(future:is_failed(), "start failure")
  local job = new_job()
  t:patch_table(vim.uv, "new_timer", function()
    return nil
  end)
  future = new_status().collect()
  t.assert_true(future:is_failed(), "timer failure")
  t.assert_nil(job.options, "no native job started without a poll timer")
end)

t:test("poll scheduling coalesces while the editor is busy", function()
  local job = new_job()
  local queued = {}
  t:patch_table(vim, "schedule", function(callback)
    queued[#queued + 1] = callback
  end)
  local future = new_status().collect()
  vim.wait(30, function()
    return false
  end, 1)
  t.assert_eq(1, #queued, "one pending poll callback")
  job.state = "completed"
  queued[1]()
  t.assert_true(future:is_done(), "queued poll publishes")
end)

t:test("exit cancels active jobs and prevents new work", function()
  local job = new_job()
  local status = new_status()
  require("era.m.git.job").setup()
  t:defer(function()
    vim.api.nvim_del_augroup_by_name("DotModuleGitJobs")
  end)
  local future = status.collect()
  vim.api.nvim_exec_autocmds("VimLeavePre", { group = "DotModuleGitJobs" })
  t.assert_true(future:is_done(), "exit settled active Future")
  t.assert_true(future:is_failed(), "exit does not publish")
  t.assert_eq(1, job.disposed, "exit disposed native job")
  t.assert_true(status.collect():is_failed(), "no query after exit")
end)

t:run()
