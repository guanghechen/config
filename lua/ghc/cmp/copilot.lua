local __module_name__ = "ghc.cmp.copilot"

---@class ghc.cmp.copilot
---@field public config                 ICopilotConfig
local M = {}

local Methods = vim.lsp.protocol.Methods

---@class ICopilotConfig
---@field public max_items              integer   Maximum number of items to return
---@field public timeout_ms             integer   Request timeout in milliseconds
---@field public debounce_ms            integer   Debounce delay in milliseconds
---@field public show_kind_icon         boolean   Show kind icon in completions
---@field public show_kind_name         boolean   Show kind name in completions

---Default configuration
local default_config = {
  max_items = 3,
  timeout_ms = 2000,
  debounce_ms = 500,
  show_kind_icon = true,
  show_kind_name = true,
}

---Validate and create configuration
---@param opts                          ?ICopilotConfig
---@return ICopilotConfig
local function create_config(opts)
  opts = opts or {}

  vim.validate({
    max_items = { opts.max_items, "number", true },
    timeout_ms = { opts.timeout_ms, "number", true },
    debounce_ms = { opts.debounce_ms, "number", true },
    show_kind_icon = { opts.show_kind_icon, "boolean", true },
    show_kind_name = { opts.show_kind_name, "boolean", true },
  })

  return vim.tbl_deep_extend("force", default_config, opts)
end

---Get Copilot LSP client
---@return vim.lsp.Client?
local function get_copilot_client()
  local clients = vim.lsp.get_clients({
    bufnr = 0,
    method = Methods.textDocument_inlineCompletion,
  })

  for _, client in ipairs(clients) do
    if client.name and string.find(string.lower(client.name), "copilot") then
      return client
    end
  end

  return nil
end

---Check if Copilot is enabled
---@return boolean
local function is_copilot_enabled()
  local has_copilot_lua, copilot_client = pcall(require, "copilot.client")
  if has_copilot_lua and copilot_client then
    return not copilot_client.is_disabled()
  end

  return vim.g.copilot_enabled ~= 0
end

---Create LSP params for inline completion
---@param winnr                         integer
---@return table
local function create_lsp_params(winnr)
  return vim.tbl_deep_extend("force", vim.lsp.util.make_position_params(winnr, "utf-16"), {
    formattingOptions = {
      insertSpaces = vim.bo.expandtab,
      tabSize = vim.fn.shiftwidth(),
    },
    context = {
      triggerKind = 2, -- inline_automatic
    },
  })
end

---Get first line length of text
---@param text                          string
---@return integer
local function get_first_line_length(text)
  if not text or text == "" then
    return 0
  end

  local first_line = text:match("^[^\r\n]*")
  return first_line and #first_line or 0
end

---Remove common indentation from text
---@param text                          string
---@return string
local function unindent(text)
  if not text or text == "" then
    return ""
  end

  local lines = vim.split(text, "\n")

  -- Remove leading/trailing empty lines
  while #lines > 0 and lines[1] == "" do
    table.remove(lines, 1)
  end
  while #lines > 0 and lines[#lines] == "" do
    table.remove(lines)
  end

  if #lines == 0 then
    return ""
  end

  -- Find common indentation
  local min_indent = math.huge
  for _, line in ipairs(lines) do
    if line ~= "" then
      local indent = line:match("^%s*")
      min_indent = math.min(min_indent, #indent)
    end
  end

  if min_indent == math.huge then
    min_indent = 0
  end

  -- Remove common indentation
  local result_lines = {}
  for _, line in ipairs(lines) do
    if line == "" then
      table.insert(result_lines, "")
    else
      table.insert(result_lines, line:sub(min_indent + 1))
    end
  end

  return table.concat(result_lines, "\n")
end

---Transform LSP completion items to blink items
---@param completions                   table[]
---@param config                        ICopilotConfig
---@return blink.cmp.CompletionItem[]
local function transform_completions(completions, config)
  local items = {}

  for i, completion in ipairs(completions) do
    if i > config.max_items then
      break
    end

    if completion and completion.insertText and completion.range then
      -- Create a copy of the range and update end position
      local range = vim.deepcopy(completion.range)
      if range["end"] then
        range["end"].character = get_first_line_length(completion.insertText)
      end

      local unindented_text = unindent(completion.insertText)

      ---@type blink.cmp.CompletionItem
      local item = {
        label = unindented_text,
        textEdit = {
          newText = completion.insertText,
          range = range,
        },
        detail = unindented_text,
        source_id = "copilot",
        source_name = "Copilot",
        cursor_column = 0,
      }

      if config.show_kind_icon then
        item.kind_icon = eve.icon.kind.Copilot
      end

      if config.show_kind_name then
        item.kind_name = "Copilot"
      end

      table.insert(items, item)
    end
  end

  return items
end

---Constructor for the Copilot source
---@param opts                          ?ICopilotConfig
---@return ghc.cmp.copilot
function M.new(opts)
  local self = setmetatable({}, { __index = M })
  self.config = create_config(opts)
  return self
end

---Check if source is enabled
---@return boolean
function M:enabled()
  return get_copilot_client() ~= nil and is_copilot_enabled()
end

---Get completions from Copilot
---@param ctx                           blink.cmp.Context
---@param callback                      fun(response: blink.cmp.CompletionResponse): nil
---@return fun()? cancellation_function
---@diagnostic disable-next-line: unused-local
function M:get_completions(ctx, callback)
  local client = get_copilot_client()

  if not client or client:is_stopped() then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local winnr = vim.api.nvim_get_current_win()
  if not vim.api.nvim_win_is_valid(winnr) then
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  local params = create_lsp_params(winnr)
  local request_id = nil

  -- Send LSP request
  local success, id_or_error = pcall(function()
    return client:request(Methods.textDocument_inlineCompletion, params, function(err, result)
      if err then
        std.reporter.warn({
          from = __module_name__,
          subject = "lsp_request_error",
          message = string.format("Copilot LSP request failed: %s", tostring(err.message or err)),
        })
        callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
        return
      end

      if not result or not result.items or #result.items == 0 then
        callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
        return
      end

      local items = transform_completions(result.items, self.config)

      callback({
        items = items,
        is_incomplete_forward = false,
        is_incomplete_backward = false,
      })
    end)
  end)

  if not success then
    std.reporter.warn({
      from = __module_name__,
      subject = "request_creation_failed",
      message = string.format("Failed to create LSP request: %s", tostring(id_or_error)),
    })
    callback({ items = {}, is_incomplete_forward = false, is_incomplete_backward = false })
    return
  end

  request_id = id_or_error

  -- Return cancellation function
  return function()
    if request_id and client and not client:is_stopped() then
      pcall(function()
        if type(request_id) == "number" then
          client:cancel_request(request_id)
        end
      end)
    end
  end
end

return M
