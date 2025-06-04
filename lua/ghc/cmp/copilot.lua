---see https://github.com/fang2hou/blink-copilot/blob/71102fe2fa1616353f8cb315bb8b85db0812a218/lua/blink-copilot/source.lua#L1

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
---@param client vim.lsp.Client
---@param req_id integer?
function util.cancel_request(client, req_id)
  if client and req_id then
    client:cancel_request(req_id)
  end
end

---Get the LSP params for the first completion
function util.get_lsp_params()
  return vim.tbl_deep_extend("force", vim.lsp.util.make_position_params(0, "utf-16"), {
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
---@param params table
function util.to_cycling_lsp_params(params)
  return vim.tbl_deep_extend("force", params, {
    context = {
      triggerKind = trigger_kind.inline_invoked,
    },
  })
end

---Get the completions from Copilot LSP
---The arguments from copilot.vim
---@param client vim.lsp.Client
---@param params table
---@param cb lsp.Handler
function util.get_completions_from_lsp(client, params, cb)
  return client:request("textDocument/inlineCompletion", params, cb)
end

---Recalculate the length of the first line of the text
---Modified from copilot-cmp
---@param text string
---@param sep? string
---@return integer
function util.length_of_first_line(text, sep)
  sep = sep or (text:find("\r") and "\r" or "\n") or "\n"

  if not string.find(text, "[\r|\n]") then
    return #text
  end

  local matched = string.match(text, "([^" .. sep .. "]+)")
  return matched and #matched or #text
end

---Remove the common indent from the text
---@param text string
---@return string
function util.unindent(text)
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
---@param completions table[]
---@param kind_name? string
---@param kind_icon? string
---@param kind_hl? string
---@return blink.cmp.CompletionItem[]
function util.lsp_completion_items_to_blink_items(completions, kind_name, kind_icon, kind_hl)
  ---@type blink.cmp.CompletionItem[]
  local items = {}

  for _, completion in ipairs(completions) do
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

  ---@type ghc.cmp.copilot.config
  local config = {
    max_completions = 3,
    max_attempts = 4,
    kind_name = "Copilot",
    kind_icon = eve.icon.kind.Copilot,
    kind_hl = "BlinkCmpKindCopilot",
    debounce = 200,
    auto_refresh = {
      backward = true,
      forward = true,
    },
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

  local copilot_lua_clients = vim.lsp.get_clients({ name = "copilot" })
  local copilot_vim_clients = vim.lsp.get_clients({ name = "GitHub Copilot" })

  if copilot_lua_clients and copilot_lua_clients[1] then
    self.client = copilot_lua_clients[1]
    local ok, clt = pcall(require, "copilot.client")
    self.is_copilot_enabled = function()
      return ok and clt and not clt.is_disabled()
    end

    return
  end

  self.client = copilot_vim_clients and copilot_vim_clients[1]
  self.is_copilot_enabled = function()
    return vim.g.copilot_enabled ~= 0
  end
end

---Reset the context
---@param ts integer
function M:reset(ts)
  util.cancel_request(self.client, self.context and self.context.first_req_id)
  util.cancel_request(self.client, self.context and self.context.cycling_req_id)

  ---@class CompletionContext
  self.context = {
    cache = {},
    completions = {},
    state = nil,
    first_req_id = nil,
    cycling_req_id = nil,
    start_ts = ts,
  }
end

---Add new completions to the context
---@param items blink.cmp.CompletionItem[]
function M:add_new_completions(items)
  local new_completions = {}

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
---@param ctx blink.cmp.Context
---@param resolve fun(self: blink.cmp.CompletionResponse): nil
function M:get_completions(ctx, resolve)
  if not self.client or not self.is_copilot_enabled() then
    return
  end

  local current_state = { bufnr = ctx.bufnr, id = ctx.id, cursor = ctx.cursor }
  if vim.deep_equal(current_state, self.context.state) then
    resolve({
      is_incomplete_forward = self.config.auto_refresh.forward,
      is_incomplete_backward = self.config.auto_refresh.backward,
      items = self.context.completions,
    })
    return
  end

  local now = util.timestamp()

  if self.config.debounce ~= false and type(self.config.debounce) == "number" then
    local since = now - self.context.start_ts
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
    local co = coroutine.running()
    local lsp_params = util.get_lsp_params()

    ---@type lsp.Handler
    local function handle_lsp_response(err, response)
      coroutine.resume(co, not err and response and response.items)
    end

    ---@param is_initial_request boolean
    local function send_completion_request(is_initial_request)
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
        items = self:add_new_completions(blink_items),
      })
    end

    -- Get the first completions
    if send_completion_request(true) then
      process_and_resolve_items()
      self.context.first_req_id = nil
      self.context.state = current_state
    end

    -- Attempt to get more completions
    lsp_params = util.to_cycling_lsp_params(lsp_params)
    local attempts_made = 0
    while
      now == self.context.start_ts -- If new blink request comes in, stop further attempts
      and #self.context.completions < self.config.max_completions
      and attempts_made < self.config.max_attempts
    do
      attempts_made = attempts_made + 1
      if send_completion_request(false) then
        process_and_resolve_items()
        self.context.cycling_req_id = nil
      end
    end
  end)()
end

return M
