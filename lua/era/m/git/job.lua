---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.git.job" ---@type string

local POLL_MS = 5 ---@type integer
local CANCELLED = "Operation cancelled" ---@type string
local pending = {} ---@type table<yoz.git.StatusJob|yoz.git.IgnoreJob|yoz.git.BlameJob, fun(): nil>
local exiting = false ---@type boolean

---@class era.m.git.job
local M = {}

---Lua owns scheduling; native jobs own their workers and cancellation acknowledgement.
---@param start                         fun(): yoz.git.StatusJob|yoz.git.IgnoreJob|yoz.git.BlameJob
---@param token                         ?stl.c.CancellationToken
---@return stl.c.Future
function M.run(start, token)
  return stl.c.Future.new(function(resolve, reject)
    if exiting or (token and token:is_cancelled()) then
      reject(CANCELLED)
      return
    end
    local timer = vim.uv.new_timer()
    if not timer then
      reject("Failed to allocate Git query poll timer")
      return
    end
    local started, job = pcall(start)
    if not started then
      timer:close()
      reject(tostring(job))
      return
    end
    local settled = false
    local scheduled = false
    local cancellation = nil ---@type stl.c.IUnsubscribable|nil

    ---@param ok                        boolean
    ---@param result                    yoz.git.StatusSnapshot|yoz.git.IgnoreReport|yoz.git.BlameSnapshot|string
    ---@return nil
    local function finish(ok, result)
      if settled then
        return
      end
      settled = true
      pending[job] = nil
      if cancellation then
        cancellation:unsubscribe()
        cancellation = nil
      end
      timer:stop()
      timer:close()
      job:dispose()
      if ok then
        resolve(result)
      else
        reject(result)
      end
    end

    ---@return nil
    local function poll()
      if settled then
        return
      end
      local ok, state, result, err = pcall(job.poll, job)
      if not ok then
        finish(false, tostring(state))
      elseif state ~= "running" then
        if exiting or (token and token:is_cancelled()) or state == "cancelled" then
          finish(false, CANCELLED)
        elseif state == "completed" then
          finish(true, result)
        else
          finish(false, tostring(err or "Git query failed"))
        end
      end
    end

    pending[job] = function()
      finish(false, CANCELLED)
    end
    if token then
      cancellation = token:on_cancel(function()
        job:cancel()
      end)
    end
    timer:start(0, POLL_MS, function()
      if settled or scheduled then
        return
      end
      scheduled = true
      vim.schedule(function()
        scheduled = false
        poll()
      end)
    end)
  end)
end

---@return nil
function M.setup()
  local group = vim.api.nvim_create_augroup("DotModuleGitJobs", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      exiting = true
      for job in pairs(pending) do
        job:cancel()
      end
      -- Bound the exit wait while workers kill and reap their Git processes.
      vim.wait(100, function()
        return next(pending) == nil
      end, 1)
      for _, finish in pairs(pending) do
        finish()
      end
    end,
  })
end

return M
