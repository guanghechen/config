---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.nvimbar.queue" ---@type string

---@class era.m.nvimbar.queue.ITask
---@field public callback               ?fun(): nil
---@field public batchable              boolean

local M = {}
local tasks = {} ---@type table<integer, era.m.nvimbar.queue.ITask>
local first, last = 1, 0
local deadlines = {} ---@type table<table, { at: number, callback: fun(): nil }>
local timer = assert(vim.uv.new_timer())
local closed = false
local scheduled_at = nil ---@type number|nil
local pending = false
timer:unref()

local arm ---@type fun(): nil

---@param callback                      fun(): nil
---@return nil
local function invoke(callback)
  local ok, err = xpcall(callback, debug.traceback)
  if not ok then
    stl.reporter.error({ from = __module_name__, subject = "dispatch", details = { error = err } })
  end
end

---@return nil
local function tick()
  if closed then
    return
  end

  local now = vim.uv.hrtime() / 1e6
  local expired = {}
  for key, deadline in pairs(deadlines) do
    if deadline.at <= now then
      expired[#expired + 1] = { key = key, deadline = deadline }
    end
  end
  for _, entry in ipairs(expired) do
    if deadlines[entry.key] == entry.deadline then
      deadlines[entry.key] = nil
      invoke(entry.deadline.callback)
    end
  end

  local stop_at = vim.uv.hrtime() + 1e6
  local ran = false
  repeat
    local task = tasks[first]
    if task == nil or (task.callback ~= nil and ran and not task.batchable) then
      break
    end
    tasks[first] = nil
    first = first + 1
    if first > last then
      first, last = 1, 0
    end
    local callback = task.callback
    task.callback = nil
    if callback ~= nil then
      invoke(callback)
      ran = true
      if not task.batchable then
        break
      end
    end
  until vim.uv.hrtime() >= stop_at
  pending = false
  arm()
end

---@return nil
local function dispatch()
  scheduled_at = nil
  pending = true
  vim.schedule(tick)
end

-- Cold work owns a turn; warm batches yield when their one-millisecond budget is spent.
---@return nil
arm = function()
  if closed or pending then
    return
  end
  local now = vim.uv.hrtime() / 1e6
  local delay = first <= last and 1 or nil ---@type number|nil
  if delay == nil then
    for _, deadline in pairs(deadlines) do
      local remaining = math.max(1, math.ceil(deadline.at - now))
      delay = delay and math.min(delay, remaining) or remaining
    end
  end
  if delay then
    local at = now + delay
    if scheduled_at == nil or at < scheduled_at then
      scheduled_at = at
      timer:start(delay, 0, dispatch)
    end
  else
    scheduled_at = nil
    timer:stop()
  end
end

---@param callback                      fun(): nil
---@param batchable                     ?boolean
---@return era.m.nvimbar.queue.ITask|nil
function M.add(callback, batchable)
  if closed then
    return
  end
  last = last + 1
  local task = { callback = callback, batchable = batchable == true }
  tasks[last] = task
  arm()
  return task
end

--- Release cancelled work immediately; its empty slot does not consume a cold turn.
---@param task                          era.m.nvimbar.queue.ITask
---@return nil
function M.cancel(task)
  task.callback = nil
  arm()
end

---@param key                           table
---@param timeout                       number
---@param callback                      fun(): nil
---@return nil
function M.watch(key, timeout, callback)
  if closed then
    return
  end
  deadlines[key] = { at = vim.uv.hrtime() / 1e6 + timeout, callback = callback }
  arm()
end

---@param key                           table
---@return nil
function M.unwatch(key)
  deadlines[key] = nil
  arm()
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  once = true,
  callback = function()
    closed = true
    tasks, deadlines = {}, {}
    timer:stop()
    timer:close()
  end,
})

return M
