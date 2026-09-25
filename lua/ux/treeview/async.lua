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
local M = {}

---@return boolean
local function resume()
  wake_revision = wake_revision + 1
  local resumed = false
  for owner in pairs(suspended) do
    suspended[owner], watchers[owner], resumed = nil, true, true
  end
  return resumed
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
  for owner in pairs(watchers) do
    local observed = wake_revision
    local ok, busy = pcall(owner._poll, owner)
    if not ok then
      watchers[owner] = nil
      M.report(busy)
    elseif busy == nil then
      -- A callback may complete a new request after this poll's event drain.
      if watchers[owner] and observed == wake_revision then
        watchers[owner], suspended[owner] = nil, true
      end
      active = active or observed ~= wake_revision
    else
      active = active or busy
    end
  end
  if timer and next(pending) == nil and next(watchers) == nil then
    timer:stop()
    timer:close()
    timer = nil
  elseif timer then
    timer:set_repeat(active and 1 or 5)
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
local function start()
  if exiting then
    return
  end
  timer = timer or assert(vim.uv.new_timer(), "Treeview poll timer allocation failed")
  timer:start(0, 1, tick)
end

---@param ticket                        yoz.ux.treeview.Ticket
---@return stl.c.Future
function M.run(ticket)
  if exiting then
    return Future.resolve(M.rejected("Disposed", "Neovim is exiting"))
  end
  if resume() then
    start()
  end
  return Future.new(function(resolve)
    local done, value = ticket:poll()
    if done then
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
  start()
end

---@param owner                         table
---@return nil
function M.unwatch(owner)
  watchers[owner], suspended[owner] = nil, nil
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  group = vim.api.nvim_create_augroup("UxTreeviewFutures", { clear = true }),
  callback = function()
    exiting = true
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
