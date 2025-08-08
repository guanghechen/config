---see https://github.com/fang2hou/blink-copilot/blob/bdc45bbbed2ec252b3a29f4adecf031e157b5573/lua/blink-copilot/source.lua#L1

local __module_name__ = "ghc.cmp.copilot" ---@type string
local Methods = vim.lsp.protocol.Methods

---@class ghc.cmp.copilot.config
---@field public max_completions        integer  Maximum number of completions to show
---@field public max_attempts           integer  Maximum number of attempts to fetch completions
---@field public kind_name              string   The name of the kind
---@field public kind_icon              string   The icon of the kind
---@field public kind_hl                string   The icon of the kind
---@field public debounce               integer|false Debounce time in milliseconds
---@field public auto_refresh           ?{ backward?: boolean, forward ?: boolean } Whether to auto-refresh completions

local util = {}

---@enum trigger_kind
local trigger_kind = {
  inline_invoked = 1,
  inline_automatic = 2,
}

---Cancel the LSP request
---@param client                        ?vim.lsp.Client
---@param req_id                        ?integer
function util.cancel_request(client, req_id)
  if client and req_id and not client:is_stopped() then
    local success, err = pcall(function()
      client:cancel_request(req_id)
    end)
    if not success then
      std.reporter.warn({
        from = __module_name__,
        subject = "cancel_request_failed",
        message = string.format("Failed to cancel LSP request: %s", tostring(err)),
      })
    end
  end
end

---Get the LSP params for the first completion
---@param winnr                        integer
function util.get_lsp_params(winnr)
  return vim.tbl_deep_extend("force", vim.lsp.util.make_position_params(winnr, "utf-16"), {
    formattingOptions = {
      insertSpaces = vim.bo.expandtab,
      tabSize = vim.fn.shiftwidth(),
    },
    context = {
      triggerKind = trigger_kind.inline_automatic,
    },
  })
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

---Get the completions from Copilot LSP
---The arguments from copilot.vim
---@param client                        vim.lsp.Client
---@param params                        table
---@param cb                            lsp.Handler
function util.get_completions_from_lsp(client, params, cb)
  if not client or client:is_stopped() then
    cb(
      { code = -1, message = "LSP client is not available" },
      nil,
      { method = Methods.textDocument_inlineCompletion, client_id = client and client.id or nil }
    )
    return false, nil
  end

  local success, request_id = pcall(function()
    return client:request(Methods.textDocument_inlineCompletion, params, cb)
  end)

  if not success then
    local error_msg = tostring(request_id)
    -- Handle specific "Resource temporarily unavailable" errors more gracefully
    if string.find(error_msg:lower(), "resource") and string.find(error_msg:lower(), "unavailable") then
      -- This is likely an EAGAIN error - don't spam logs for this common issue
      cb(
        {
          code = 11,
          message = "Resource temporarily unavailable - will retry later",
        },
        nil,
        {
          method = Methods.textDocument_inlineCompletion,
          client_id = client and client.id or nil,
        }
      )
      return false, nil
    end

    std.reporter.warn({
      from = __module_name__,
      subject = "lsp_request_failed",
      message = string.format("Failed to send LSP request: %s", error_msg),
    })
    cb(
      { code = -1, message = "Failed to send LSP request" },
      nil,
      { method = Methods.textDocument_inlineCompletion, client_id = client and client.id or nil }
    )
    return false, nil
  end

  return success, request_id
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

    local k = 0 ---@type integer
    for j = 1, min_len do
      if string.byte(common_prefix, j, j) ~= string.byte(current_indent, j, j) then
        break
      end
      k = k + 1
    end

    if k > 0 then
      new_prefix = new_prefix .. string.sub(common_prefix, 1, k)
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

---Transforms a Copilot completion items to blink completion item
---@param completions                   table[]
---@param kind_name                     ?string
---@param kind_icon                     ?string
---@param kind_hl                       ?string
---@return blink.cmp.CompletionItem[]
function util.lsp_completion_items_to_blink_items(completions, kind_name, kind_icon, kind_hl)
  ---@type blink.cmp.CompletionItem[]
  local items = {}

  if not completions or #completions == 0 then
    return items
  end

  for _, completion in ipairs(completions) do
    -- Validate completion structure
    if not completion or not completion.insertText or not completion.range then
      goto continue
    end

    -- Validate range structure
    if not completion.range["end"] or type(completion.range["end"]) ~= "table" then
      goto continue
    end

    -- The original range is the cursor position, so we need to update it to the end of the line
    completion.range["end"].character = util.length_of_first_line(completion.insertText)

    local unindented_text = util.unindent(completion.insertText)

    table.insert(items, {
      label = unindented_text,
      kind_name = kind_name,
      kind_icon = kind_icon,
      kind_hl = kind_hl,
      textEdit = { newText = completion.insertText, range = completion.range },
      detail = unindented_text,
    })

    ::continue::
  end

  return items
end

---Get the current time in milliseconds
---@return integer timestamp
function util.timestamp()
  ---@diagnostic disable-next-line: undefined-field
  return math.floor(vim.uv.hrtime() / 1e6)
end

---@class ghc.cmp.copilot
---@field public config                 ghc.cmp.copilot.config
local M = {}
M.__index = M

---The constructor for the completion provider
function M.new()
  local self = setmetatable({}, M)

  local max_completions = 2 ---@type integer
  local max_attempts = 1 ---@type integer
  local kind_name = "Copilot" ---@type string
  local kind_icon = eve.icon.kind.Copilot ---@type string
  local kind_hl = "BlinkCmpKindCopilot" ---@type string
  local debounce = 800 ---@type integer
  local auto_refresh = { ---@type { backward: boolean, forward: boolean }
    backward = true,
    forward = true,
  }

  ---@type ghc.cmp.copilot.config
  local config = {
    max_completions = max_completions,
    max_attempts = max_attempts,
    kind_name = kind_name,
    kind_icon = kind_icon,
    kind_hl = kind_hl,
    debounce = debounce,
    auto_refresh = auto_refresh,
  }
  self.config = config
  self:detect_lsp_client()
  self:reset(0)
  return self
end

---Detect the LSP client
function M:detect_lsp_client()
  if self.client and not self.client:is_stopped() then
    return
  end

  local lsp_clients = vim.lsp.get_clients({ bufnr = 0, method = Methods.textDocument_inlineCompletion })
  for _, client in ipairs(lsp_clients) do
    if string.find(string.lower(client.name), "copilot") then
      self.client = client
      self.is_copilot_enabled = function()
        local copilot_lua, clt = pcall(require, "copilot.client")
        return (copilot_lua and clt and not clt.is_disabled()) or (vim.g.copilot_enabled ~= 0)
      end
      break
    end
  end
end

---Reset the context
---@param ts                            integer
function M:reset(ts)
  -- Cancel existing requests
  util.cancel_request(self.client, self.context and self.context.first_req_id)
  util.cancel_request(self.client, self.context and self.context.cycling_req_id)

  -- Clear debounce timer
  if self.debounce_timer then
    std.timer.clear_timer(self.debounce_timer)
    self.debounce_timer = nil
  end

  ---@class CompletionContext
  self.context = {
    cache = {},
    completions = {},
    state = nil,
    first_req_id = nil,
    cycling_req_id = nil,
    start_ts = ts,
    last_request_ts = 0,
    min_request_interval = 200, -- Minimum 200ms between requests
  }
end

---Add new completions to the context
---@param items                         blink.cmp.CompletionItem[]
function M:add_new_completions(items)
  local new_completions = {} ---@type blink.cmp.CompletionItem[]

  for _, item in ipairs(items) do
    if #self.context.completions < self.config.max_completions then
      if not self.context.cache[item.label] then
        self.context.cache[item.label] = true
        table.insert(self.context.completions, item)
        table.insert(new_completions, item)
      end
    end
  end

  return new_completions
end

---Implement the get_completions method of the completion provider
---@param ctx                           blink.cmp.Context
---@param resolve                       fun(self: blink.cmp.CompletionResponse): nil
function M:get_completions(ctx, resolve)
  if not self.client or not self.is_copilot_enabled or not self.is_copilot_enabled() then
    return
  end

  local winnr = vim.api.nvim_get_current_win() ---@type integer
  local bufnr = ctx.bufnr ---@type integer
  local id = ctx.id ---@type integer
  local cursor = ctx.cursor ---@type { row: integer, col: integer }
  local current_state = { bufnr = bufnr, id = id, cursor = cursor }

  if vim.deep_equal(current_state, self.context.state) then
    local is_incomplete_forward = self.config.auto_refresh.forward ---@type boolean
    local is_incomplete_backward = self.config.auto_refresh.backward ---@type boolean
    local items = self.context.completions ---@type blink.cmp.CompletionItem[]

    resolve({
      is_incomplete_forward = is_incomplete_forward,
      is_incomplete_backward = is_incomplete_backward,
      items = items,
    })
    return
  end

  local now = util.timestamp() ---@type integer

  if self.config.debounce ~= false and type(self.config.debounce) == "number" then
    local since = now - self.context.start_ts ---@type integer
    if since < self.config.debounce then
      if self.debounce_timer then
        std.timer.clear_timer(self.debounce_timer)
        self.debounce_timer = nil
      end
      self.debounce_timer = std.timer.set_timeout(function()
        self.debounce_timer = nil
        self:get_completions(ctx, resolve)
      end, self.config.debounce)
      return
    end
  end

  self:reset(now)

  coroutine.wrap(function()
    local success, err = pcall(function()
      if not vim.api.nvim_win_is_valid(winnr) then
        return
      end

      local lsp_params = util.get_lsp_params(winnr)
      local co = coroutine.running()

      ---@type lsp.Handler
      local function handle_lsp_response(err, response)
        coroutine.resume(co, not err and response and response.items)
      end

      ---@param is_initial_request      boolean
      local function send_completion_request(is_initial_request)
        if not self.client or self.client:is_stopped() then
          return false
        end

        -- Rate limiting: prevent too frequent requests
        local current_time = util.timestamp()
        if current_time - self.context.last_request_ts < self.context.min_request_interval then
          return false
        end
        self.context.last_request_ts = current_time

        local request_success, request_id = util.get_completions_from_lsp(self.client, lsp_params, handle_lsp_response)

        if request_success then
          if is_initial_request then
            self.context.first_req_id = request_id
          else
            self.context.cycling_req_id = request_id
          end
        end
        return request_success
      end

      local function process_and_resolve_items()
        local lsp_items = coroutine.yield()
        if self.context.start_ts ~= now or not lsp_items or #lsp_items == 0 then
          return
        end

        local blink_items = util.lsp_completion_items_to_blink_items(
          lsp_items,
          self.config.kind_name,
          self.config.kind_icon,
          self.config.kind_hl
        )

        resolve({
          is_incomplete_forward = self.config.auto_refresh.forward,
          is_incomplete_backward = self.config.auto_refresh.backward,
          items = self:add_new_completions(vim.deepcopy(blink_items)),
        })
      end

      -- Get the first completions
      if send_completion_request(true) then
        process_and_resolve_items()
        self.context.first_req_id = nil
        self.context.state = current_state
      end

      -- Attempt to get more completions with longer delay between attempts
      lsp_params = util.to_cycling_lsp_params(lsp_params)
      local attempts_made = 0 ---@type integer
      while
        now == self.context.start_ts -- If new blink request comes in, stop further attempts
        and #self.context.completions < self.config.max_completions
        and attempts_made < self.config.max_attempts
      do
        attempts_made = attempts_made + 1

        -- Add delay between cycling requests to reduce pressure
        if attempts_made >= 1 then
          vim.wait(100) -- 100ms delay between additional requests
        end

        if send_completion_request(false) then
          process_and_resolve_items()
          self.context.cycling_req_id = nil
        else
          -- If request failed, break to avoid rapid retries
          break
        end
      end
    end)

    if not success then
      std.reporter.error({
        from = __module_name__,
        subject = "completion_error",
        message = string.format("Copilot completion error: %s", tostring(err)),
      })
    end
  end)()
end

return M
