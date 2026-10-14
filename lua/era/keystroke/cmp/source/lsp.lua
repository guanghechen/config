---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.source.lsp" ---@type string

local Context = require("era.keystroke.cmp.context")
local Item = require("era.keystroke.cmp.item")
local new_table = require("table.new")
local cache = {} ---@type table<integer, { context: era.keystroke.cmp.IContext, response: era.keystroke.cmp.IResponse }>
---@class era.keystroke.cmp.ILspRequest
---@field public client                 vim.lsp.Client
---@field public context                era.keystroke.cmp.IContext
---@field public latest                 era.keystroke.cmp.IContext
---@field public callback               fun(response: era.keystroke.cmp.IResponse): nil
---@field public dispatch               ?era.keystroke.cmp.RequestDispatch
---@field public id                     ?integer
---@field public timer                  ?uv.uv_timer_t
---@field public expired                boolean
local requests = {} ---@type table<integer, era.keystroke.cmp.ILspRequest>
local default_fields = { "insertTextFormat", "insertTextMode", "data", "commitCharacters" }
local nullable_fields = {
  insertText = true,
  textEditText = true,
  insertTextFormat = true,
  insertTextMode = true,
  filterText = true,
  sortText = true,
  detail = true,
  labelDetails = { detail = true, description = true },
  kind = true,
  deprecated = true,
  tags = true,
  textEdit = { range = true, insert = true, replace = true },
  additionalTextEdits = true,
  commitCharacters = true,
  documentation = true,
  command = true,
}
local M = {}

---@generic T: table
---@param record                        T
---@param fields                        table<string, boolean|table<string, boolean>>
---@return T
local function normalize(record, fields)
  -- Follow protocol fields only; data and command arguments retain opaque JSON nulls.
  local result = record
  for key, value in pairs(record) do
    local field = fields[key]
    if field ~= nil then
      local normalized = value
      if value == vim.NIL then
        normalized = nil
      elseif type(field) == "table" and type(value) == "table" then
        normalized = normalize(value, field)
      end
      if normalized ~= value then
        if result == record then
          result = vim.tbl_extend("force", {}, record)
        end
        result[key] = normalized
      end
    end
  end
  return result
end

---@param context                       era.keystroke.cmp.IContext
---@param client                        vim.lsp.Client
---@param result                        ?lsp.CompletionList|lsp.CompletionItem[]
---@return era.keystroke.cmp.IResponse
function M.response(context, client, result)
  if type(result) ~= "table" then
    return { items = {}, incomplete = true }
  end
  local items = type(result.items) == "table" and result.items or result
  local response = { items = new_table(#items, 0), incomplete = result.isIncomplete == true } ---@type era.keystroke.cmp.IResponse
  local defaults = type(result.itemDefaults) == "table" and normalize(result.itemDefaults, nullable_fields) or {}
  local has_defaults = next(defaults) ~= nil
  local default_range = defaults.editRange
  -- A published aggregation contains one response per client.
  local id_prefix = "lsp:" .. client.id .. ":"
  for index, raw in ipairs(items) do
    if type(raw) == "table" and type(raw.label) == "string" then
      local copied = false
      if has_defaults then
        for _, key in ipairs(default_fields) do
          if (raw[key] == nil or (key ~= "data" and raw[key] == vim.NIL)) and raw[key] ~= defaults[key] then
            if not copied then
              raw = vim.tbl_extend("force", {}, raw)
              copied = true
            end
            raw[key] = defaults[key]
          end
        end
      end
      if Item.optional(raw.textEdit) == nil and type(default_range) == "table" then
        if not copied then
          raw = vim.tbl_extend("force", {}, raw)
        end
        local text = Item.optional(raw.textEditText) or Item.optional(raw.insertText) or raw.label
        if type(default_range.start) == "table" then
          raw.textEdit = {
            newText = text,
            range = default_range --[[@as lsp.Range]],
          }
        else
          raw.textEdit = { newText = text, insert = default_range.insert, replace = default_range.replace }
        end
      end
      local edit = Item.optional(raw.textEdit)
      local range = edit and (Item.optional(edit.range) or edit.insert)
      if
        range == nil
        or (range ~= vim.NIL and range.start.line == context.row and range["end"].line == context.row)
      then
        local item = Item.new(context, "lsp", raw, client, id_prefix .. index)
        if item.start_col <= context.col then
          response.items[#response.items + 1] = item
        end
      end
    end
  end
  return response
end

---@param request                       era.keystroke.cmp.ILspRequest
---@return nil
local function close_timer(request)
  local timer = request.timer
  request.timer = nil
  if timer ~= nil then
    timer:stop()
    timer:close()
  end
end

---@param request                       era.keystroke.cmp.ILspRequest
---@return nil
local function cancel_request(request)
  requests[request.client.id] = nil
  close_timer(request)
  if request.id ~= nil then
    request.client:cancel_request(request.id)
  end
end

---@param client                        vim.lsp.Client
---@param context                       era.keystroke.cmp.IContext
---@param callback                      fun(response: era.keystroke.cmp.IResponse): nil
---@param dispatch                      ?era.keystroke.cmp.RequestDispatch
---@return nil
local function start_request(client, context, callback, dispatch)
  ---@type era.keystroke.cmp.ILspRequest
  local request =
    { client = client, context = context, latest = context, callback = callback, dispatch = dispatch, expired = false }
  requests[client.id] = request
  local entry = cache[client.id]
  local provider = client.server_capabilities.completionProvider
  local character = context.line:sub(context.col, context.col)
  local trigger_kind = 1
  if context.trigger ~= "manual" then
    if
      type(provider) == "table"
      and type(provider.triggerCharacters) == "table"
      and vim.list_contains(provider.triggerCharacters, character)
    then
      trigger_kind = 2
    elseif entry ~= nil and entry.response.incomplete and Context.extends(entry.context, context) then
      trigger_kind = 3
    end
  end
  local params = {
    textDocument = { uri = vim.uri_from_bufnr(context.bufnr) },
    position = {
      line = context.row,
      character = client.offset_encoding == "utf-8" and context.col
        or vim.str_utfindex(context.line, client.offset_encoding, context.col, false),
    },
    context = { triggerKind = trigger_kind, triggerCharacter = trigger_kind == 2 and character or nil },
  }
  local settled = false

  ---@param result                      ?lsp.CompletionList|lsp.CompletionItem[]
  ---@return nil
  local function finish(result)
    if settled or requests[client.id] ~= request then
      return
    end
    settled = true
    close_timer(request)
    request.id = nil
    local response = M.response(context, client, result)
    cache[client.id] = { context = context, response = response }
    local reusable = Context.extends(context, request.latest)
    local queued = not Context.same_input(context, request.latest) and (response.incomplete or not reusable)
    if not queued then
      requests[client.id] = nil
    end
    if reusable then
      request.callback(queued and { items = response.items, incomplete = true, pending = true } or response)
    end
    -- Publishing may replace or cancel the subscriber; only its current owner may start the next request.
    if queued and requests[client.id] == request then
      start_request(client, request.latest, request.callback, request.dispatch)
    end
  end

  local submitted = false
  ---@return nil
  local function submit()
    if requests[client.id] ~= request then
      return
    end
    submitted = true
    local ok, request_id = client:request("textDocument/completion", params, function(err, result)
      finish(err == nil and result or nil)
    end, context.bufnr)
    if not ok then
      finish(nil)
    elseif not settled and requests[client.id] == request then
      request.id = request_id
      request.timer = assert(vim.uv.new_timer())
      request.timer:start(
        2000,
        0,
        vim.schedule_wrap(function()
          if settled or requests[client.id] ~= request then
            return
          end
          close_timer(request)
          request.expired = true
          request.callback({ items = {}, incomplete = true, pending = false })
          if requests[client.id] == request and not Context.same_input(context, request.latest) then
            -- A hung server must not hold the latest query indefinitely; same-context late replies remain useful.
            cancel_request(request)
            start_request(client, request.latest, request.callback, request.dispatch)
          end
        end)
      )
    end
  end
  if dispatch ~= nil then
    dispatch(submit)
  else
    submit()
  end
  if not submitted and requests[client.id] == request then
    cancel_request(request)
  end
end

---@param context                       era.keystroke.cmp.IContext
---@param callback                      fun(response: era.keystroke.cmp.IResponse): nil
---@param dispatch                      ?era.keystroke.cmp.RequestDispatch
---@return fun(keep_transport?: boolean): nil
function M.complete(context, callback, dispatch)
  local clients = vim.lsp.get_clients({ bufnr = context.bufnr, method = "textDocument/completion" })
  local cancelled = false
  local callbacks = {} ---@type table<integer, fun(response: era.keystroke.cmp.IResponse): nil>
  local responses = {} ---@type table<integer, era.keystroke.cmp.IResponse>
  local live = {} ---@type table<integer, boolean>

  ---@return nil
  local function publish()
    if cancelled then
      return
    end
    if #clients == 1 and responses[clients[1].id] ~= nil then
      callback(responses[clients[1].id])
      return
    end
    local result = { items = {}, incomplete = false, pending = false } ---@type era.keystroke.cmp.IResponse
    for _, client in ipairs(clients) do
      local response = responses[client.id]
      if response ~= nil then
        vim.list_extend(result.items, response.items)
        result.incomplete = result.incomplete or response.incomplete
        result.pending = result.pending or response.pending == true
      else
        result.incomplete, result.pending = true, true
      end
    end
    callback(result)
  end

  for _, client in ipairs(clients) do
    live[client.id] = true
    local entry = cache[client.id]
    local request = requests[client.id]
    if
      context.trigger ~= "manual"
      and entry ~= nil
      and not entry.response.incomplete
      and Context.extends(entry.context, context)
    then
      if request ~= nil then
        cancel_request(request)
      end
      responses[client.id] = entry.response
    else
      ---@param response                era.keystroke.cmp.IResponse
      ---@return nil
      local function receive(response)
        responses[client.id] = response
        publish()
      end
      callbacks[client.id] = receive
      if
        context.trigger ~= "manual"
        and request ~= nil
        and not request.expired
        and Context.compatible(request.context, context)
      then
        request.latest, request.callback, request.dispatch = context, receive, dispatch
      else
        if request ~= nil then
          cancel_request(request)
        end
        start_request(client, context, receive, dispatch)
      end
    end
  end
  for client_id in pairs(cache) do
    if not live[client_id] then
      cache[client_id] = nil
    end
  end
  for client_id, request in pairs(requests) do
    if not live[client_id] then
      cancel_request(request)
    end
  end
  if #clients == 0 or next(responses) ~= nil then
    publish()
  end
  return function(keep_transport)
    cancelled = true
    for client_id, receive in pairs(callbacks) do
      local request = requests[client_id]
      if request ~= nil and request.callback == receive then
        if keep_transport then
          -- Input already changed, but its next context has not been captured yet.
          request.latest = request.context
        else
          cancel_request(request)
        end
      end
    end
  end
end

---@param raw                           lsp.CompletionItem
---@return lsp.CompletionItem
local function lua_ls_detail(raw)
  local documentation = raw.documentation
  if raw.detail == nil or raw.detail == "" or type(documentation) ~= "table" or documentation.kind ~= "markdown" then
    return raw
  end
  -- LuaLS puts the full signature in the first Lua fence and only its type in detail.
  local signature, rest = (Item.optional(documentation.value) or ""):match("^```lua\r?\n(.-)\r?\n```[ \t]*(.*)$")
  if signature == nil or not signature:find(raw.detail, 1, true) or (rest ~= "" and not rest:match("^\r?\n")) then
    return raw
  end
  return vim.tbl_extend("force", {}, raw, {
    detail = signature,
    documentation = vim.tbl_extend("force", {}, documentation, { value = rest }),
  })
end

---@param item                          era.keystroke.cmp.IItem
---@param callback                      fun(raw: lsp.CompletionItem): nil
---@return (fun(): nil)|nil
function M.resolve(item, callback)
  local original = normalize(item.raw, nullable_fields)
  local client = item.client_id and vim.lsp.get_client_by_id(item.client_id) or nil
  local provider = client and client.server_capabilities.completionProvider or nil
  ---@param raw                         lsp.CompletionItem
  ---@return nil
  local function publish(raw)
    callback(client ~= nil and client.name == "lua_ls" and lua_ls_detail(raw) or raw)
  end
  if client == nil or type(provider) ~= "table" or provider.resolveProvider ~= true then
    publish(original)
    return nil
  end
  local cancelled = false
  local ok, request_id = client:request("completionItem/resolve", item.raw, function(err, raw)
    if not cancelled then
      publish(
        err == nil and type(raw) == "table" and vim.tbl_extend("force", {}, original, normalize(raw, nullable_fields))
          or original
      )
    end
  end, item.context.bufnr)
  if not ok then
    publish(original)
  end
  return function()
    cancelled = true
    if request_id ~= nil then
      client:cancel_request(request_id)
    end
  end
end

return M
