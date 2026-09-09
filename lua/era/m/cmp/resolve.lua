---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.resolve" ---@type string

local protocol = require("era.m.cmp.protocol")
local REQUEST_TIMEOUT = 2000
local cache = setmetatable({}, { __mode = "k" }) ---@type table<table, era.m.cmp.resolve.IRequest>

---@class era.m.cmp.resolve.IListener
---@field public active                 boolean
---@field public notify                 fun(err: lsp.ResponseError|nil, result: lsp.CompletionItem|nil): nil

---@class era.m.cmp.resolve.IRequest
---@field public bufnr                  integer
---@field public client                 vim.lsp.Client
---@field public request_id             integer|nil
---@field public timer                  uv.uv_timer_t|nil
---@field public listeners              table<era.m.cmp.resolve.IListener, boolean>
---@field public settled                boolean
---@field public cancelled              boolean
---@field public result                 lsp.CompletionItem|nil
---@field public error                  lsp.ResponseError|nil

---@class era.m.cmp.resolve
local M = {}

---@param state                         era.m.cmp.resolve.IRequest
---@return nil
local function stop_timer(state)
  local timer = state.timer
  state.timer = nil
  if timer ~= nil and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

---@param state                         era.m.cmp.resolve.IRequest
---@return nil
local function cancel_request(state)
  stop_timer(state)
  if state.request_id ~= nil then
    pcall(state.client.cancel_request, state.client, state.request_id)
    state.request_id = nil
  end
end

---@param listener                      era.m.cmp.resolve.IListener
---@param err                           lsp.ResponseError|nil
---@param result                        lsp.CompletionItem|nil
---@return nil
local function notify(listener, err, result)
  if not listener.active then
    return
  end
  listener.active = false
  local ok, callback_error = xpcall(listener.notify, debug.traceback, err, result)
  if not ok then
    stl.reporter.error({
      from = __module_name__,
      subject = "callback",
      message = "Completion resolve callback failed.",
      details = callback_error,
    })
  end
end

---@param item                          era.m.cmp.ICompletionItem
---@param callback                      fun(err: lsp.ResponseError|nil, result: era.m.cmp.ICompletionItem): nil
---@param usage_key                     ?string
---@param snapshot                      ?fun(): string[]|nil
---@return fun(): nil
function M.request(item, callback, usage_key, snapshot)
  local origin = item._era_cmp_origin
  local client = origin ~= nil and vim.lsp.get_client_by_id(origin.client_id) or nil
  if client == nil or not client:supports_method("completionItem/resolve") then
    callback(nil, item)
    return function() end
  end
  local key = origin.candidate or origin
  local state = cache[key]
  if state ~= nil and state.client ~= client then
    state.cancelled = true
    state.listeners = {}
    cache[key] = nil
    cancel_request(state)
    state = nil
  end
  local listener = {
    active = true,
    notify = function(err, result)
      if result == nil then
        callback(err, item)
        return
      end
      local ok, normalized = xpcall(function()
        local preserved = type(item.additionalTextEdits) == "table"
            and next(item.additionalTextEdits) ~= nil
            and item.additionalTextEdits
          or nil
        return protocol.normalize(
          result,
          origin.context,
          origin.start_col,
          origin.target_start_col,
          origin.suffix_bytes,
          usage_key,
          client,
          preserved,
          snapshot ~= nil and snapshot() or nil,
          origin.source_context,
          origin.candidate
        )
      end, debug.traceback)
      if ok then
        callback(err, normalized or item)
      else
        stl.reporter.error({
          from = __module_name__,
          subject = "normalize",
          message = "Failed to normalize resolved completion item.",
          details = normalized,
        })
        callback({ code = vim.lsp.protocol.ErrorCodes.InternalError, message = "Completion resolve failed" }, item)
      end
    end,
  } ---@type era.m.cmp.resolve.IListener
  if state ~= nil and state.settled then
    notify(listener, state.error, state.result)
    return function() end
  end
  local start = state == nil
  if state == nil then
    state = {
      bufnr = origin.context.bufnr,
      client = client,
      request_id = nil,
      timer = nil,
      listeners = {},
      settled = false,
      cancelled = false,
      result = nil,
      error = nil,
    }
    cache[key] = state
  end
  state.listeners[listener] = true

  if start then
    ---@param err                       lsp.ResponseError|nil
    ---@param result                    lsp.CompletionItem|nil
    ---@return nil
    local function finish(err, result)
      if state.cancelled or state.settled then
        return
      end
      state.settled = true
      state.error = err
      state.result = result
      state.request_id = nil
      stop_timer(state)
      if result == nil then
        cache[key] = nil
      end
      local listeners = state.listeners
      state.listeners = {}
      for current in pairs(listeners) do
        notify(current, err, result)
      end
    end
    state.timer = vim.defer_fn(function()
      cancel_request(state)
      finish(nil, nil)
    end, REQUEST_TIMEOUT)
    local request_item = vim.deepcopy(origin.item)
    local invoked, sent, request_id = xpcall(function()
      return client:request("completionItem/resolve", request_item, function(err, result)
        if state.cancelled or state.settled then
          return
        end
        if err ~= nil or type(result) ~= "table" then
          finish(err, nil)
          return
        end
        local resolved = vim.tbl_extend("force", {}, request_item, result)
        local prepared, prepare_error = protocol.prepare(resolved, nil)
        if prepared == nil then
          stl.reporter.error({
            from = __module_name__,
            subject = "response",
            message = "Invalid completion resolve response.",
            details = prepare_error,
          })
          finish(
            { code = vim.lsp.protocol.ErrorCodes.InternalError, message = "Invalid completion resolve response" },
            nil
          )
        else
          finish(nil, prepared)
        end
      end, origin.context.bufnr)
    end, debug.traceback)
    if not state.settled then
      if invoked and sent and request_id ~= nil then
        state.request_id = request_id
      else
        if not invoked then
          stl.reporter.warn({
            from = __module_name__,
            subject = client.name,
            message = "Failed to start completion resolve request.",
            details = sent,
          })
        end
        finish(nil, nil)
      end
    end
  end

  return function()
    if not listener.active then
      return
    end
    listener.active = false
    state.listeners[listener] = nil
    if not state.settled and next(state.listeners) == nil then
      state.cancelled = true
      cache[key] = nil
      cancel_request(state)
    end
  end
end

---@param bufnr                         integer
---@return nil
function M.clear(bufnr)
  for key, state in pairs(cache) do
    if state.bufnr == bufnr then
      state.cancelled = true
      state.listeners = {}
      cancel_request(state)
      cache[key] = nil
    end
  end
end

return M
