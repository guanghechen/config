---@diagnostic disable-next-line: unused-local
local __module_name__ = "ux.treeview.async" ---@type string

local Future = require("stl.c.future")
local pending = {} ---@type table<yoz.ux.treeview.Ticket, fun(value: any): nil>
local watchers = setmetatable({}, { __mode = "k" }) ---@type table<table, boolean>
local suspended = setmetatable({}, { __mode = "k" }) ---@type table<table, boolean>
local timer ---@type uv.uv_timer_t|nil
local scheduled = false
local exiting = false
local wake_revision = 0
local listen, start
local M = {}

---@return nil
local function resume()
  wake_revision = wake_revision + 1
  for owner in pairs(suspended) do
    suspended[owner], watchers[owner] = nil, true
    listen(owner)
  end
end

---@param code                          string
---@param message                       string
---@return ux.treeview.IRejected
function M.rejected(code, message)
  return { kind = "Rejected", error = { code = code, message = message } }
end

---@param error                         any
---@return nil
function M.report(error)
  local message = type(error) == "table" and (error.message or vim.inspect(error)) or tostring(error)
  stl.reporter.error({ from = __module_name__, message = message })
end

---@param owner                         table
---@return nil
local function disconnect(owner)
  local notification = owner._notification
  owner._notification = nil
  if notification then
    -- Stop native writers before closing their read endpoint.
    notification.subscription:close()
    if not notification.reader:is_closing() then
      notification.reader:read_stop()
      notification.reader:close()
    end
  end
end

---@return nil
local function poll()
  scheduled = false
  for ticket, resolve in pairs(pending) do
    local ok, done, value = pcall(ticket.poll, ticket)
    if not ok or done then
      pending[ticket] = nil
      -- A completed native request may publish effects after an idle owner suspended.
      resume()
      resolve(ok and value or M.rejected("Disposed", tostring(done)))
    end
  end
  local active = next(pending) ~= nil
  local polling = active
  for owner in pairs(watchers) do
    local observed = wake_revision
    local ok, busy = pcall(owner._poll, owner)
    if not ok then
      watchers[owner] = nil
      disconnect(owner)
      M.report(busy)
    elseif busy == nil then
      -- A callback may complete a new request after this poll's event drain.
      if watchers[owner] and observed == wake_revision then
        watchers[owner], suspended[owner] = nil, true
        disconnect(owner)
      end
      active = active or observed ~= wake_revision
    else
      active = active or busy
    end
    if watchers[owner] then
      polling = polling or busy == true or observed ~= wake_revision or owner._notification == nil
    end
  end
  if timer and not polling then
    timer:stop()
    timer:close()
    timer = nil
  elseif timer then
    timer:set_repeat(active and 1 or 16)
  elseif polling then
    start()
  end
end

---@return nil
local function tick()
  if scheduled then
    return
  end
  scheduled = true
  vim.schedule(poll)
end

---@return nil
start = function()
  if exiting then
    return
  end
  timer = timer or assert(vim.uv.new_timer(), "Treeview poll timer allocation failed")
  timer:start(0, 1, tick)
end

---@param owner                         table
---@return nil
listen = function(owner)
  if exiting or owner._notification or owner._notification_failed or not owner._native then
    return
  end
  -- The native writer coalesces to one byte; its endpoint need not use OVERLAPPED IO.
  local descriptors, error = vim.uv.pipe({ nonblock = true }, { nonblock = false })
  if not descriptors then
    owner._notification_failed = true
    M.report(error)
    return
  end
  local reader, opened
  local ok, subscription = pcall(function()
    reader = assert(vim.uv.new_pipe(false))
    assert(reader:open(descriptors.read))
    opened = true
    return owner._native:subscribe(descriptors.write)
  end)
  vim.uv.fs_close(descriptors.write)
  if not ok then
    if not opened then
      vim.uv.fs_close(descriptors.read)
    end
    if reader then
      reader:close()
    end
    owner._notification_failed = true
    M.report(subscription)
    return
  end
  owner._notification = { reader = reader, subscription = subscription }
  -- A live pipe must not retain its Lua owner or its native notification lease.
  local weak = setmetatable({ owner }, { __mode = "v" })
  local started, failure = reader:read_start(vim.schedule_wrap(function(error, bytes)
    local current = weak[1]
    if not current then
      if not reader:is_closing() then
        reader:close()
      end
      return
    end
    local notification = current._notification
    if not notification or notification.reader ~= reader then
      return
    end
    local acknowledged, failure = pcall(notification.subscription.acknowledge, notification.subscription)
    if error or bytes == nil or not acknowledged then
      disconnect(current)
      current._notification_failed = true
      tick()
      M.report(error or failure or "Treeview notification stream closed")
      return
    end
    -- Clear the signal before draining state so a racing publication sends a new wakeup.
    wake_revision = wake_revision + 1
    tick()
  end))
  if not started then
    disconnect(owner)
    owner._notification_failed = true
    M.report(failure)
  end
end

---@param ticket                        yoz.ux.treeview.Ticket
---@return stl.c.Future
function M.run(ticket)
  if exiting then
    return Future.resolve(M.rejected("Disposed", "Neovim is exiting"))
  end
  resume()
  return Future.new(function(resolve)
    local done, value = ticket:poll()
    if done then
      start()
      resolve(value)
      return
    end
    pending[ticket] = resolve
    start()
  end)
end

---@param owner                         table
---@return nil
function M.watch(owner)
  wake_revision = wake_revision + 1
  suspended[owner] = nil
  watchers[owner] = true
  owner._notification_failed = nil
  listen(owner)
  start()
end

---@param owner                         table
---@return nil
function M.unwatch(owner)
  watchers[owner], suspended[owner] = nil, nil
  disconnect(owner)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("UxTreeviewFutures", { clear = true }),
  callback = function()
    exiting = true
    for owner in pairs(watchers) do
      disconnect(owner)
    end
    for ticket, resolve in pairs(pending) do
      pending[ticket] = nil
      resolve(M.rejected("Disposed", "Neovim is exiting"))
    end
    if timer then
      timer:stop()
      timer:close()
      timer = nil
    end
  end,
})

return M
