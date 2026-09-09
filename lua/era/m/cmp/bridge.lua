---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.bridge" ---@type string

local context_api = require("era.m.cmp.context")

local source = require("era.m.cmp.source")
local protocol = require("era.m.cmp.protocol")
local snapshots = require("era.m.cmp.snapshot")
local resolver = require("era.m.cmp.resolve")
local util = require("era.m.cmp.source.util")

local M = {}

local COMMAND = protocol.COMMAND
local INITIAL_PUBLISH_DELAY = 40 ---@type integer
local MAX_SUPERSEDED_SESSIONS = 8 ---@type integer
local REQUEST_TIMEOUT = 2000 ---@type integer
local TRIGGER_PARAMETER_HINTS = "editor.action.triggerParameterHints"
local TRIGGER_SUGGEST = "editor.action.triggerSuggest"
local failed_clients = {} ---@type table<integer, boolean>
local failed_items = {} ---@type table<string, boolean>
local history_state = { usage = yoz.cmp.usage({}), keys = {}, labels = {} } ---@type era.m.cmp.snapshot.IHistory
local completion_cache = {} ---@type table<integer, { context: era.m.cmp.IContext, responses: table<integer, era.m.cmp.protocol.IResponse>, snapshot: era.m.cmp.snapshot.ISnapshot|nil }>

---@param timer                         uv.uv_timer_t|nil
local function close_timer(timer)
  if timer ~= nil and not timer:is_closing() then
    timer:stop()
    timer:close()
  end
end

---@param labels                        table<string, table<string, boolean>>
---@param key                           string
local function add_history_label(labels, key)
  local source, label = key:match("^([^%z]*)%z[^%z]*%z([^%z]*)%z")
  if source == nil then
    source, label = key:match("^([^%z]*)%z(.*)$")
  end
  if source == nil or label == nil then
    return
  end
  local source_labels = labels[source] or {} ---@type table<string, boolean>
  source_labels[label] = true
  labels[source] = source_labels
end

---@param values                        table<string, any>
---@return table<string, table<string, boolean>>, table<string, boolean>
local function collect_history_indexes(values)
  local labels = {} ---@type table<string, table<string, boolean>>
  local keys = {} ---@type table<string, boolean>
  for key in pairs(values) do
    add_history_label(labels, key)
    keys[key] = true
  end
  return labels, keys
end

---@param params                        lsp.CompletionParams
---@param client                        vim.lsp.Client
---@param context                       era.m.cmp.IContext
---@return lsp.CompletionParams
local function client_params(params, client, context)
  local forwarded = vim.deepcopy(params) ---@type lsp.CompletionParams
  forwarded.position.character = vim.str_utfindex(context.line, client.offset_encoding or "utf-16", context.col, false)
  local forwarded_context = forwarded.context
  if
    forwarded_context ~= nil
    and forwarded_context.triggerKind == vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter
  then
    local characters = vim.tbl_get(client.server_capabilities or {}, "completionProvider", "triggerCharacters") or {}
    if not vim.list_contains(characters, forwarded_context.triggerCharacter) then
      forwarded.context = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.Invoked }
    end
  end
  return forwarded
end

---@param owner                         string
---@param err                           any
local function report_invalid_item(owner, err)
  if err == nil then
    failed_items[owner] = nil
    return
  end
  if failed_items[owner] then
    return
  end
  failed_items[owner] = true
  stl.reporter.warn({
    from = __module_name__,
    subject = owner,
    message = "Skipped invalid completion item.",
    details = err,
  })
end

---@param previous                      era.m.cmp.IContext
---@param current                       era.m.cmp.IContext
---@return boolean
local function extends_context(previous, current)
  return context_api.extends(previous, current)
end

---@param result                        vim.lsp.CompletionResult
---@param owner                         string
---@param context                       era.m.cmp.IContext
---@return era.m.cmp.protocol.ICandidate[]
local function response_items(result, owner, context)
  local raw_items = type(result) == "table" and (result.items or result) or nil
  if type(raw_items) ~= "table" then
    return {}
  end
  local defaults = result.items and result.itemDefaults or nil
  local items = {} ---@type era.m.cmp.protocol.ICandidate[]
  for _, raw_item in ipairs(raw_items) do
    local item, err = protocol.prepare(raw_item, defaults)
    if item ~= nil then
      items[#items + 1] = { item = item, context = context }
    else
      report_invalid_item(owner, err)
    end
  end
  return items
end

---@param result                        vim.lsp.CompletionResult
---@return boolean
local function response_is_incomplete(result)
  return type(result) == "table" and result.isIncomplete == true
end

---@param preferred                     era.m.cmp.protocol.ICandidate[]
---@param fallback                      era.m.cmp.protocol.ICandidate[]|nil
---@param encoding                      string
---@return era.m.cmp.protocol.ICandidate[]
local function merge_response_items(preferred, fallback, encoding)
  local output = {} ---@type era.m.cmp.protocol.ICandidate[]
  local buckets = {} ---@type table<string, era.m.cmp.protocol.ICandidate|era.m.cmp.protocol.ICandidate[]>
  ---@param left                        era.m.cmp.protocol.ICandidate
  ---@param right                       era.m.cmp.protocol.ICandidate
  ---@return boolean
  local function equal(left, right)
    return protocol.equal(left.item, right.item, left.context, right.context, encoding)
  end
  for _, items in ipairs({ preferred, fallback or {} }) do
    for _, candidate in ipairs(items) do
      local key = candidate.item.label
      local bucket = buckets[key]
      local duplicate = false
      if bucket == nil then
        buckets[key] = candidate
      elseif bucket.item ~= nil then
        duplicate = equal(bucket, candidate)
        if not duplicate then
          buckets[key] = { bucket, candidate }
        end
      else
        for _, previous in ipairs(bucket) do
          if equal(previous, candidate) then
            duplicate = true
            break
          end
        end
        if not duplicate then
          bucket[#bucket + 1] = candidate
        end
      end
      if not duplicate then
        output[#output + 1] = candidate
      end
    end
  end
  return output
end

---@param context                       era.m.cmp.IContext
---@return boolean
local function is_context_current(context)
  if not vim.api.nvim_buf_is_valid(context.bufnr) or vim.api.nvim_get_current_buf() ~= context.bufnr then
    return false
  end

  if vim.api.nvim_get_current_line() ~= context.line then
    return false
  end
  if not vim.api.nvim_get_mode().mode:match("^[iR]") then
    return false
  end
  local cursor = vim.api.nvim_win_get_cursor(0) ---@type integer[]
  return cursor[1] - 1 == context.row and cursor[2] == context.col
end

---@class era.m.cmp.bridge.ISession
---@field public context                era.m.cmp.IContext
---@field public key                    string
---@field public callback               fun(err: lsp.ResponseError|nil, result: lsp.CompletionList|nil): nil
---@field public is_current             fun(): boolean
---@field public local_done             boolean
---@field public local_cancel           fun()|nil
---@field public local_snapshot         (fun(): lsp.CompletionList)|nil
---@field public local_result           lsp.CompletionList
---@field public requests               table<integer, { done: boolean, request_id: integer|nil }>
---@field public responses              table<integer, era.m.cmp.protocol.IResponse>
---@field public pending                integer
---@field public initial_published      boolean
---@field public publish_pending        boolean
---@field public finished               boolean
---@field public cancelled              boolean
---@field public initial_timer          uv.uv_timer_t|nil
---@field public publish_initial        fun(): nil
---@field public superseded             boolean
---@field public timer                  uv.uv_timer_t|nil
---@field public cached_snapshot        era.m.cmp.snapshot.ISnapshot|nil

local sessions = {} ---@type table<integer, era.m.cmp.bridge.ISession>
local superseded_sessions = {} ---@type table<integer, era.m.cmp.bridge.ISession[]>

---@param context                       era.m.cmp.IContext
---@return string
local function context_key(context)
  return table.concat({ context.bufnr, context.row, context.col, context.line }, "\0")
end

---@param session                       era.m.cmp.bridge.ISession
local function cancel_outstanding(session)
  if not session.local_done and type(session.local_cancel) == "function" then
    pcall(session.local_cancel)
  end
  for client_id, request in pairs(session.requests) do
    if not request.done and request.request_id ~= nil then
      local client = vim.lsp.get_client_by_id(client_id)
      if client ~= nil then
        pcall(client.cancel_request, client, request.request_id)
      end
    end
  end
end

---@param session                       era.m.cmp.bridge.ISession
local function remove_superseded(session)
  local bufnr = session.context.bufnr ---@type integer
  local entries = superseded_sessions[bufnr]
  if entries == nil then
    return
  end
  for index, candidate in ipairs(entries) do
    if candidate == session then
      table.remove(entries, index)
      break
    end
  end
  if #entries == 0 then
    superseded_sessions[bufnr] = nil
  end
end

---@param session                       era.m.cmp.bridge.ISession
local function dispose_session(session)
  if session.cancelled then
    return
  end
  session.cancelled = true
  close_timer(session.initial_timer)
  close_timer(session.timer)
  cancel_outstanding(session)
  remove_superseded(session)
  if sessions[session.context.bufnr] == session then
    sessions[session.context.bufnr] = nil
  end
end

---@param session                       era.m.cmp.bridge.ISession
local function supersede_session(session)
  if session.cancelled or session.superseded then
    return
  end
  session.superseded = true
  close_timer(session.initial_timer)
  if not session.local_done then
    if type(session.local_cancel) == "function" then
      pcall(session.local_cancel)
    end
    session.local_done = true
    session.pending = session.pending - 1
  end
  if sessions[session.context.bufnr] == session then
    sessions[session.context.bufnr] = nil
  end
  if session.pending <= 0 then
    session.finished = true
    close_timer(session.timer)
    session.timer = nil
    return
  end
  local entries = superseded_sessions[session.context.bufnr] or {}
  while #entries >= MAX_SUPERSEDED_SESSIONS do
    dispose_session(entries[1])
  end
  entries[#entries + 1] = session
  superseded_sessions[session.context.bufnr] = entries
end

---@param session                       era.m.cmp.bridge.ISession
local function update_local_snapshot(session)
  if session.local_done or session.local_snapshot == nil then
    return
  end
  local ok, result = xpcall(session.local_snapshot, debug.traceback)
  if ok then
    session.local_result = result
  else
    session.local_snapshot = nil
    stl.reporter.error({
      from = __module_name__,
      subject = "local",
      message = "Failed to snapshot local completion results.",
      details = result,
    })
  end
end

---@param session                       era.m.cmp.bridge.ISession
---@param callback                      fun(err: lsp.ResponseError|nil, result: lsp.CompletionList|nil): nil
---@return boolean
local function publish_session(session, callback)
  if not session.is_current() then
    callback(nil, { isIncomplete = false, items = {} })
    return true
  end

  local ok, result, snapshot = xpcall(function()
    if session.cached_snapshot ~= nil then
      local cached_snapshot = session.cached_snapshot
      session.cached_snapshot = nil
      return snapshots.rank(session.context, cached_snapshot, history_state, report_invalid_item), nil
    end
    update_local_snapshot(session)
    return snapshots.build(session.context, session.local_result, session.responses, history_state, report_invalid_item)
  end, debug.traceback)
  if ok then
    if snapshot ~= nil then
      local cached = completion_cache[session.context.bufnr]
      if cached ~= nil and context_key(cached.context) == context_key(session.context) then
        cached.snapshot = snapshot
      end
    end
    callback(nil, result)
    return true
  end

  stl.reporter.error({
    from = __module_name__,
    subject = "merge",
    message = "Failed to merge completion responses.",
    details = result,
  })
  callback({ code = vim.lsp.protocol.ErrorCodes.InternalError, message = "Completion merge failed" }, nil)
  return false
end

---@param session                       era.m.cmp.bridge.ISession
---@return nil
local function schedule_publish(session)
  if session.cancelled or session.superseded or not session.initial_published or session.publish_pending then
    return
  end
  session.publish_pending = true
  vim.schedule(function()
    if session.cancelled or sessions[session.context.bufnr] ~= session then
      return
    end
    session.publish_pending = false
    if not session.is_current() then
      dispose_session(session)
      return
    end
    local ok, published = xpcall(publish_session, debug.traceback, session, session.callback)
    if not ok then
      stl.reporter.error({
        from = __module_name__,
        subject = "publish",
        message = "Failed to publish completion results.",
        details = published,
      })
      dispose_session(session)
    elseif not published then
      dispose_session(session)
    elseif session.finished and sessions[session.context.bufnr] == session then
      sessions[session.context.bufnr] = nil
    end
  end)
end

---@param session                       era.m.cmp.bridge.ISession
---@return nil
local function finish_background(session)
  if session.pending ~= 0 or session.finished then
    return
  end
  session.finished = true
  close_timer(session.timer)
  if session.initial_published then
    schedule_publish(session)
  else
    session.publish_initial()
  end
end

---@param params                        lsp.CompletionParams
---@param callback                      fun(err: lsp.ResponseError|nil, result: lsp.CompletionList|nil): nil
---@param bufnr                         ?integer
---@param is_current                    ?fun(): boolean
---@return fun(): nil
function M.complete(params, callback, bufnr, is_current)
  local context = context_api.from_params(params, bufnr)
  if context == nil then
    callback(nil, { isIncomplete = false, items = {} })
    return function() end
  end
  local current = is_current or function()
    return is_context_current(context)
  end
  if not current() then
    callback(nil, { isIncomplete = false, items = {} })
    return function() end
  end

  local key = context_key(context)
  local existing = sessions[context.bufnr]
  if existing ~= nil then
    if not existing.cancelled and existing.key == key then
      existing.publish_pending = false
      existing.callback = callback
      existing.is_current = current
      local published = publish_session(existing, callback)
      if not published then
        dispose_session(existing)
      elseif existing.finished and sessions[context.bufnr] == existing then
        sessions[context.bufnr] = nil
      end
      return function() end
    end
    if extends_context(existing.context, context) then
      supersede_session(existing)
    else
      dispose_session(existing)
    end
  end

  local clients = vim.lsp.get_clients({ bufnr = context.bufnr, method = "textDocument/completion" })
  local responses = {} ---@type table<integer, era.m.cmp.protocol.IResponse>
  local request_clients = {} ---@type vim.lsp.Client[]
  local cached = completion_cache[context.bufnr]
  local extends_cached = cached ~= nil and extends_context(cached.context, context) ---@type boolean
  local incomplete_refresh = params.context ~= nil
    and params.context.triggerKind == vim.lsp.protocol.CompletionTriggerKind.TriggerForIncompleteCompletions ---@type boolean
  local publish_cached_immediately = extends_cached and incomplete_refresh ---@type boolean
  if extends_cached then
    for _, client in ipairs(clients) do
      local response = cached.responses[client.id]
      if response ~= nil then
        responses[client.id] = response
      end
      if response == nil or not incomplete_refresh or response.is_incomplete then
        request_clients[#request_clients + 1] = client
      end
    end
  else
    request_clients = clients
  end
  local session = {
    context = context,
    key = key,
    callback = callback,
    is_current = current,
    local_done = false,
    local_cancel = nil,
    local_snapshot = nil,
    local_result = { isIncomplete = true, items = {} },
    requests = {},
    responses = responses,
    pending = #request_clients + 1,
    initial_published = false,
    publish_pending = false,
    finished = false,
    cancelled = false,
    superseded = false,
    initial_timer = nil,
    publish_initial = function() end,
    timer = nil,
    cached_snapshot = publish_cached_immediately and cached.snapshot or nil,
  } ---@type era.m.cmp.bridge.ISession
  sessions[context.bufnr] = session
  completion_cache[context.bufnr] = { context = vim.deepcopy(context), responses = responses, snapshot = nil }

  session.publish_initial = function()
    if session.cancelled or session.initial_published or sessions[context.bufnr] ~= session then
      return
    end
    close_timer(session.initial_timer)
    session.initial_timer = nil
    session.initial_published = true
    local published = publish_session(session, session.callback)
    if (not published or session.finished) and sessions[context.bufnr] == session then
      sessions[context.bufnr] = nil
    end
  end
  if not publish_cached_immediately then
    session.initial_timer = vim.defer_fn(session.publish_initial, INITIAL_PUBLISH_DELAY)
  elseif session.cached_snapshot ~= nil then
    session.publish_initial()
  end

  session.timer = vim.defer_fn(function()
    if session.cancelled or session.finished then
      return
    end
    if session.superseded then
      dispose_session(session)
      return
    end
    if sessions[context.bufnr] ~= session then
      return
    end
    update_local_snapshot(session)
    cancel_outstanding(session)
    session.pending = 0
    session.finished = true
    schedule_publish(session)
  end, REQUEST_TIMEOUT)

  local local_ok, cancel_or_error, snapshot = xpcall(function()
    return source.complete(params, history_state.usage, function(result)
      if session.cancelled or session.finished or session.local_done then
        return
      end
      session.local_done = true
      session.local_result = result
      session.pending = session.pending - 1
      schedule_publish(session)
      finish_background(session)
    end, context.bufnr)
  end, debug.traceback)
  if local_ok then
    session.local_cancel = cancel_or_error
    session.local_snapshot = snapshot
  else
    session.local_done = true
    session.pending = session.pending - 1
    stl.reporter.error({
      from = __module_name__,
      subject = "local",
      message = "Local completion request failed.",
      details = cancel_or_error,
    })
  end

  for _, client in ipairs(request_clients) do
    local upstream = client ---@type vim.lsp.Client
    local request = { done = false, request_id = nil } ---@type { done: boolean, request_id: integer|nil }
    session.requests[upstream.id] = request
    local invoked, request_ok, request_id = xpcall(function()
      return upstream:request("textDocument/completion", client_params(params, upstream, context), function(err, result)
        if session.cancelled or request.done then
          return
        end
        request.done = true
        if session.superseded then
          session.pending = session.pending - 1
          local cached_response = completion_cache[context.bufnr]
          if err == nil and cached_response ~= nil and extends_context(context, cached_response.context) then
            local response = {
              client = upstream,
              items = response_items(result, upstream.name, context),
              is_incomplete = response_is_incomplete(result),
            }
            local previous = cached_response.responses[upstream.id]
            response.items = merge_response_items(
              previous and previous.items or {},
              response.items,
              upstream.offset_encoding or "utf-16"
            )
            if previous ~= nil then
              response.is_incomplete = previous.is_incomplete
            end
            cached_response.responses[upstream.id] = response
            cached_response.snapshot = nil
            local current = sessions[context.bufnr]
            if current ~= nil and context_key(current.context) == context_key(cached_response.context) then
              current.responses[upstream.id] = response
              schedule_publish(current)
            end
          end
          if session.pending <= 0 then
            session.finished = true
            close_timer(session.timer)
            session.timer = nil
            remove_superseded(session)
          end
          return
        end
        if session.finished then
          return
        end
        session.pending = session.pending - 1
        if err == nil then
          failed_clients[upstream.id] = nil
          local previous = session.responses[upstream.id]
          session.responses[upstream.id] = {
            client = upstream,
            items = merge_response_items(
              response_items(result, upstream.name, context),
              previous and previous.items or nil,
              upstream.offset_encoding or "utf-16"
            ),
            is_incomplete = response_is_incomplete(result),
          }
          completion_cache[context.bufnr] = {
            context = vim.deepcopy(context),
            responses = session.responses,
            snapshot = nil,
          }
        elseif
          type(err) == "table"
          and err.code ~= vim.lsp.protocol.ErrorCodes.RequestCancelled
          and not failed_clients[upstream.id]
        then
          failed_clients[upstream.id] = true
          stl.reporter.warn({
            from = __module_name__,
            subject = upstream.name,
            message = "LSP completion request failed.",
            details = err,
          })
        end
        schedule_publish(session)
        finish_background(session)
      end, context.bufnr)
    end, debug.traceback)
    if invoked and request_ok and request_id ~= nil then
      request.request_id = request_id
    elseif not request.done then
      request.done = true
      session.pending = session.pending - 1
      if not invoked and not failed_clients[upstream.id] then
        failed_clients[upstream.id] = true
        stl.reporter.warn({
          from = __module_name__,
          subject = upstream.name,
          message = "Failed to start LSP completion request.",
          details = request_ok,
        })
      end
    end
  end

  if publish_cached_immediately and not session.initial_published then
    session.publish_initial()
  end
  finish_background(session)

  return function()
    dispose_session(session)
  end
end

---@param item                          era.m.cmp.ICompletionItem
---@param callback                      fun(err: lsp.ResponseError|nil, result: era.m.cmp.ICompletionItem|nil): nil
---@param snapshot                      ?fun(): string[]|nil
---@return fun(): nil
function M.resolve(item, callback, snapshot)
  return resolver.request(item, callback, M.get_usage_key(item), snapshot)
end

---@param command                        lsp.Command
---@param context                        table
function M.execute_command(command, context)
  local payload = type(command.arguments) == "table" and command.arguments[1] or nil
  if type(payload) ~= "table" or type(payload.client_id) ~= "number" or type(payload.command) ~= "table" then
    return
  end
  local client = vim.lsp.get_client_by_id(payload.client_id) ---@type vim.lsp.Client|nil
  if client ~= nil then
    client:exec_cmd(payload.command, { bufnr = context.bufnr })
  end
end

---@param show                           fun(): nil
---@param show_signature                 fun(bufnr: integer): boolean
function M.register_commands(show, show_signature)
  vim.lsp.commands[TRIGGER_PARAMETER_HINTS] = vim.lsp.commands[TRIGGER_PARAMETER_HINTS]
    or function(_, context)
      local bufnr = context.bufnr ---@type integer|nil
      vim.schedule(function()
        if
          type(bufnr) == "number"
          and vim.api.nvim_buf_is_valid(bufnr)
          and vim.api.nvim_get_current_buf() == bufnr
          and vim.api.nvim_get_mode().mode:match("^[iR]")
        then
          show_signature(bufnr)
        end
      end)
    end
  vim.lsp.commands[TRIGGER_SUGGEST] = vim.lsp.commands[TRIGGER_SUGGEST]
    or function(_, context)
      local bufnr = context.bufnr ---@type integer|nil
      vim.schedule(function()
        if
          type(bufnr) == "number"
          and vim.api.nvim_buf_is_valid(bufnr)
          and vim.api.nvim_get_current_buf() == bufnr
          and vim.api.nvim_get_mode().mode:match("^[iR]")
        then
          show()
        end
      end)
    end
end

---@param item                           era.m.cmp.ICompletionItem
---@return string|nil
function M.get_usage_key(item)
  local meta = util.meta(item)
  if meta == nil then
    return nil
  end
  if type(meta.usage_key) == "string" then
    return meta.usage_key
  end
  local origin = item._era_cmp_origin
  if origin == nil then
    return nil
  end
  local key = protocol.usage_key(meta.source, origin.item)
  meta.usage_key = key
  return key
end

---@param value                          table<string, integer|{ count: integer, last_used: integer }|yoz.cmp.IUsageRecord>
function M.set_history(value)
  history_state.usage = yoz.cmp.usage(value)
  history_state.labels, history_state.keys = collect_history_indexes(value)
end

---@param key                            string
---@param now                            integer
function M.record_history(key, now)
  history_state.usage:record(key, now)
  add_history_label(history_state.labels, key)
  history_state.keys[key] = true
end

---@param now                            integer
---@return table<string, yoz.cmp.IUsageRecord>
function M.snapshot_history(now)
  local snapshot = history_state.usage:snapshot(now)
  history_state.labels, history_state.keys = collect_history_indexes(snapshot)
  return snapshot
end

---@param bufnr                         integer
function M.cancel(bufnr)
  local session = sessions[bufnr]
  if session ~= nil then
    dispose_session(session)
  end
end

---@param bufnr                         integer
function M.clear(bufnr)
  M.cancel(bufnr)
  local entries = superseded_sessions[bufnr]
  while entries ~= nil and entries[1] ~= nil do
    dispose_session(entries[1])
  end
  superseded_sessions[bufnr] = nil
  completion_cache[bufnr] = nil
end

---@param bufnr                         integer
---@return nil
function M.dispose(bufnr)
  M.clear(bufnr)
  resolver.clear(bufnr)
end

return M
