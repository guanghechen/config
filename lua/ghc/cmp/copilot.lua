---see https://github.com/fang2hou/blink-copilot/blob/41e91a659bd9b8cba9ba2ea68a69b52ba5a9ebd8/lua/blink-copilot/source.lua#L1

local __module_name__ = "ghc.cmp.copilot" ---@type string
local Methods = vim.lsp.protocol.Methods
local augroup = eve.nvim.augroup(string.format("%s__%s", __module_name__, "LspAttach"))

---@class ghc.cmp.copilot.config
---@field public max_completions        integer  Maximum number of completions to show
---@field public max_attempts           integer  Maximum number of attempts to fetch completions
---@field public kind_name              string   The name of the kind
---@field public kind_icon              string   The icon of the kind
---@field public kind_hl                string   The icon of the kind
---@field public debounce               integer|false Debounce time in milliseconds
---@field public auto_refresh           ?{ backward?: boolean, forward ?: boolean } Whether to auto-refresh completions
---@field public request_timeout        integer  Request timeout in milliseconds
---@field public max_concurrent_requests integer  Maximum concurrent requests
---@field public backoff_base           integer  Base backoff time in milliseconds
local config = {
  max_completions = 3,
  max_attempts = 1, -- Reduced from 2 to prevent resource exhaustion
  kind_name = "Copilot",
  kind_icon = eve.icon.kind.Copilot,
  kind_hl = "BlinkCmpKindCopilot",
  debounce = 1000, -- Increased from 800ms to reduce request frequency
  auto_refresh = {
    backward = true,
    forward = true,
  },
  request_timeout = 5000, -- 5 second timeout for requests
  max_concurrent_requests = 2, -- Limit concurrent requests
  backoff_base = 1000, -- Base backoff time
}

---@enum trigger_kind
local trigger_kind = {
  inline_invoked = 1,
  inline_automatic = 2,
}

---@class ghc.cmp.copilot.util
local util = {}

---Cancel the LSP request
---@param client                        ?vim.lsp.Client
---@param req_id                        ?integer
---@return nil
function util.cancel_request(client, req_id)
  if client and req_id and not client:is_stopped() then
    local success, err = pcall(client.cancel_request, client, req_id)
    if not success then
      std.reporter.warn({
        from = __module_name__,
        subject = "cancel_request",
        message = string.format("Failed to cancel LSP request:"),
        details = { req_id = req_id, error = err },
      })
    end
  end
end

---Get the LSP params for the first completion
---@param winnr                        integer
---@param bufnr                        integer
---@return lsp.TextDocumentPositionParams
function util.get_lsp_params(winnr, bufnr)
  local params = vim.lsp.util.make_position_params(winnr, "utf-16") ---@type lsp.TextDocumentPositionParams
  local result = vim.tbl_deep_extend("force", params, {
    formattingOptions = {
      insertSpaces = vim.bo[bufnr].expandtab,
      tabSize = vim.fn.shiftwidth(),
    },
    context = {
      triggerKind = trigger_kind.inline_automatic,
    },
  })
  return result
end

---Convert the params from first completion to cycling completion
---@param params                        table
function util.to_cycling_lsp_params(params)
  return vim.tbl_deep_extend("force", params, {
    context = {
      triggerKind = trigger_kind.inline_invoked,
    },
  })
end

---Get the completions from Copilot LSP. The arguments from copilot.vim
---@param client                        vim.lsp.Client
---@param params                        table
---@param callback                      lsp.Handler
---@param timeout_ms                    integer
---@return boolean                      status indicates whether the request was successful.
---@return integer?                     request_id Can be used with |Client:cancel_request()|.
function util.get_completions_from_lsp(client, params, callback, timeout_ms)
  local timeout_timer ---@type uv.uv_timer_t?
  local wrapped_callback = function(err, response, ctx)
    if timeout_timer then
      timeout_timer:stop()
      timeout_timer = nil
    end
    callback(err, response, ctx)
  end

  local succeed, req_id = client:request(Methods.textDocument_inlineCompletion, params, wrapped_callback)

  -- Add timeout handling
  if succeed and timeout_ms and timeout_ms > 0 then
    timeout_timer = vim.defer_fn(function()
      util.cancel_request(client, req_id)
      wrapped_callback({ code = -32700, message = "Request timeout" }, nil, nil)
    end, timeout_ms)
  end

  return succeed, req_id
end

---Recalculate the length of the first line of the text
---Modified from copilot-cmp
---@param text                          ?string
---@param sep                           ?string
---@return integer
function util.length_of_first_line(text, sep)
  if not text or text == "" then
    return 0
  end

  sep = sep or (text:find("\r") and "\r" or "\n") or "\n"
  if not string.find(text, "[\r|\n]") then
    return #text
  end

  local matched = string.match(text, "([^" .. sep .. "]+)")
  return matched and #matched or #text
end

---Remove the common indent from the text
---@param text                          ?string
---@return string
function util.unindent(text)
  if not text or text == "" then
    return ""
  end

  local lines = vim.split(text, "\n")

  -- Cleanup the empty lines
  local start_idx, end_idx = 1, #lines
  while start_idx <= #lines and lines[start_idx] == "" do
    start_idx = start_idx + 1
  end
  if start_idx > #lines then
    return ""
  end
  while end_idx >= 1 and lines[end_idx] == "" do
    end_idx = end_idx - 1
  end

  lines = vim.list_slice(lines, start_idx, end_idx)

  -- Find the common indent
  local indents = {}
  for _, line in ipairs(lines) do
    if line ~= "" then
      local indent = line:match("^%s*")
      table.insert(indents, indent)
    end
  end
  if #indents == 0 then
    return table.concat(lines, "\n")
  end

  local common_prefix = indents[1]
  for i = 2, #indents do
    local current_indent = indents[i]
    local min_len = math.min(#common_prefix, #current_indent)
    local new_prefix = ""
    for j = 1, min_len do
      if string.byte(common_prefix, j, j) ~= string.byte(current_indent, j, j) then
        break
      end
      new_prefix = new_prefix .. common_prefix:sub(j, j)
    end
    common_prefix = new_prefix
    if common_prefix == "" then
      break
    end
  end

  local processed_lines = {}
  for _, line in ipairs(lines) do
    if line == "" then
      table.insert(processed_lines, "")
    else
      local processed_line = line:gsub("^" .. common_prefix, "", 1)
      table.insert(processed_lines, processed_line)
    end
  end

  return table.concat(processed_lines, "\n")
end

---Get the current time in milliseconds
---@return integer timestamp
function util.timestamp()
  ---@diagnostic disable-next-line: undefined-field
  return math.floor(vim.uv.hrtime() / 1e6)
end

---@class ghc.cmp.copilot
---@field public client                 vim.lsp.Client|nil
---@field public active_requests        integer
---@field public last_failure_ts        integer
---@field public failure_count          integer
local M = {}
M.__index = M

function M.new()
  local self = setmetatable({}, M)
  self:detect_lsp_client()
  self:reset(0)
  self.active_requests = 0
  self.last_failure_ts = 0
  self.failure_count = 0

  vim.api.nvim_create_autocmd({ "LspAttach" }, {
    group = augroup,
    callback = function()
      self:detect_lsp_client()
    end,
  })
  return self
end

---Detect the LSP client
function M:detect_lsp_client()
  if self.client and not self.client:is_stopped() then
    return
  end

  local lsp_clients = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/inlineCompletion" })
  for _, client in ipairs(lsp_clients) do
    if string.find(string.lower(client.name), "copilot") then
      self.client = client
      break
    end
  end
end

---Check if we should apply backoff due to recent failures
---@return boolean should_backoff
---@return integer backoff_time_ms
function M:should_apply_backoff()
  local now = util.timestamp()
  if self.failure_count > 0 and now - self.last_failure_ts < (config.backoff_base * math.pow(2, self.failure_count - 1)) then
    local backoff_time = config.backoff_base * math.pow(2, self.failure_count - 1)
    return true, backoff_time
  end
  return false, 0
end

---Record a failure and update backoff state
function M:record_failure()
  self.failure_count = math.min(self.failure_count + 1, 5) -- Cap at 5 failures
  self.last_failure_ts = util.timestamp()
end

---Record a success and reset backoff state
function M:record_success()
  self.failure_count = 0
  self.last_failure_ts = 0
end

---Check if we can make a new request (rate limiting)
---@return boolean can_request
function M:can_make_request()
  if self.active_requests >= config.max_concurrent_requests then
    return false
  end

  local should_backoff, _ = self:should_apply_backoff()
  return not should_backoff
end

---Reset the context
---@param ts                            integer
function M:reset(ts)
  util.cancel_request(self.client, self.context and self.context.first_req_id)
  util.cancel_request(self.client, self.context and self.context.cycling_req_id)

  -- Decrease active request count when resetting
  if self.context and (self.context.first_req_id or self.context.cycling_req_id) then
    self.active_requests = math.max(0, self.active_requests - 1)
  end

  ---@class ghc.cmp.copilot.context
  self.context = {
    cache = {},
    items = {},
    state = nil,
    first_req_id = nil,
    cycling_req_id = nil,
    start_ts = ts,
  }
end

---Add new completions to the context
---@param items                         blink.cmp.CompletionItem[]
---@return blink.cmp.CompletionItem[]
function M:add_new_completions(items)
  local context_items = self.context.items ---@type blink.cmp.CompletionItem[]
  local next_items = {} ---@type blink.cmp.CompletionItem[]

  for _, item in ipairs(items) do
    if #context_items >= config.max_completions then
      break
    end

    if not self.context.cache[item.label] then
      self.context.cache[item.label] = true
      context_items[#context_items + 1] = item
      next_items[#next_items + 1] = item
    end
  end

  return next_items
end

---Implement the get_completions method of the completion provider
---@param ctx                           blink.cmp.Context
---@param callback                      fun(self: blink.cmp.CompletionResponse): nil
function M:get_completions(ctx, callback)
  if not self.client or not eve.context.flight.ai:snapshot() then
    callback({
      is_incomplete_forward = config.auto_refresh.forward,
      is_incomplete_backward = config.auto_refresh.backward,
      items = {},
    })
    return
  end

  -- Check rate limiting and backoff
  if not self:can_make_request() then
    local should_backoff, backoff_time = self:should_apply_backoff()
    if should_backoff then
      std.reporter.warn({
        from = __module_name__,
        subject = "rate_limit",
        message = string.format("Copilot requests rate limited, backing off for %dms", backoff_time),
      })
    end
    callback({
      is_incomplete_forward = config.auto_refresh.forward,
      is_incomplete_backward = config.auto_refresh.backward,
      items = {},
    })
    return
  end

  local current_state = { bufnr = ctx.bufnr, id = ctx.id, cursor = ctx.cursor }
  if vim.deep_equal(current_state, self.context.state) then
    callback({
      is_incomplete_forward = config.auto_refresh.forward,
      is_incomplete_backward = config.auto_refresh.backward,
      items = self.context.items,
    })
    return
  end

  local now = util.timestamp() ---@type integer
  local since = now - self.context.start_ts ---@type integer
  if since < config.debounce then
    if self.debounce_timer then
      self.debounce_timer:stop()
    end
    self.debounce_timer = vim.defer_fn(function()
      self.debounce_timer = nil
      self:get_completions(ctx, callback)
    end, config.debounce)
    return
  end

  self:reset(now)

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = ctx.bufnr or vim.api.nvim_win_get_buf(winnr) ---@type integer
  coroutine.wrap(function()
    local co = coroutine.running()
    local lsp_params = util.get_lsp_params(winnr, bufnr) ---@type lsp.TextDocumentPositionParams

    ---@type lsp.Handler
    local function handle_lsp_response(err, response)
      self.active_requests = math.max(0, self.active_requests - 1)
      if err then
        self:record_failure()
        std.reporter.warn({
          from = __module_name__,
          subject = "lsp_request_error",
          message = "Copilot LSP request failed",
          details = { error = err },
        })
      else
        self:record_success()
      end
      coroutine.resume(co, not err and response and response.items)
    end

    ---@param is_initial_request        boolean
    ---@return boolean
    local function send_completion_request(is_initial_request)
      if not self:can_make_request() then
        return false
      end

      self.active_requests = self.active_requests + 1
      local request_success, request_id = util.get_completions_from_lsp(
        self.client,
        lsp_params,
        handle_lsp_response,
        config.request_timeout
      )

      if request_success then
        if is_initial_request then
          self.context.first_req_id = request_id
        else
          self.context.cycling_req_id = request_id
        end
      else
        self.active_requests = math.max(0, self.active_requests - 1)
        self:record_failure()
      end
      return request_success
    end

    ---@return nil
    local function process_and_resolve_items()
      local completions = coroutine.yield() ---@type any[]
      if self.context.start_ts ~= now or not completions or #completions == 0 then
        return
      end

      local items = {} ---@type blink.cmp.CompletionItem[]
      for _, completion in ipairs(completions) do
        -- The original range is the cursor position, so we need to update it to the end of the line
        completion.range["end"].character = util.length_of_first_line(completion.insertText)

        local unindent_text = util.unindent(completion.insertText) ---@type string

        ---@type blink.cmp.CompletionItem
        local item = {
          label = unindent_text,
          kind = vim.lsp.protocol.CompletionItemKind.Text,
          kind_name = config.kind_name,
          kind_icon = config.kind_icon,
          kind_hl = config.kind_hl,
          detail = unindent_text,
          textEdit = {
            newText = completion.insertText,
            range = completion.range,
          },
          insertText = completion.insertText,
          insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
          source_id = "copilot",
          source_name = "Copilot",
          cursor_column = ctx.cursor[2],
        }
        items[#items + 1] = item
      end

      callback({
        is_incomplete_forward = config.auto_refresh.forward,
        is_incomplete_backward = config.auto_refresh.backward,
        items = self:add_new_completions(vim.deepcopy(items)),
      })
    end

    -- Get the first completions
    if send_completion_request(true) then
      process_and_resolve_items()
      self.context.first_req_id = nil
      self.context.state = current_state
    else
      -- Failed to send initial request, return empty results
      callback({
        is_incomplete_forward = config.auto_refresh.forward,
        is_incomplete_backward = config.auto_refresh.backward,
        items = {},
      })
      return
    end

    -- Attempt to get more completions (reduced attempts)
    lsp_params = util.to_cycling_lsp_params(lsp_params)
    for _ = 1, config.max_attempts, 1 do
      -- If new blink request comes in, stop further attempts
      if now ~= self.context.start_ts or #self.context.items >= config.max_completions then
        break
      end

      -- Skip cycling requests if we're hitting rate limits
      if not self:can_make_request() then
        break
      end

      if send_completion_request(false) then
        process_and_resolve_items()
        self.context.cycling_req_id = nil
      else
        -- Failed to send cycling request, stop trying
        break
      end
    end
  end)()
end

return M
