---@class ghc.cmp.slash.ICommand
---@field public name                   string
---@field public description            string

---@type ghc.cmp.slash.ICommand[]
local commands = {
  { name = "code-analyze", description = "Perform comprehensive code review on target" },
  { name = "code-analyze-followup", description = "Follow-up analysis after fixes" },
  { name = "code-apply", description = "Apply fixes from previous analysis" },
  { name = "code-fix-lsp", description = "Fix LSP diagnostics errors" },
  { name = "code-impl", description = "Execute coding task" },
  { name = "code-review", description = "Review code changes or verify fixes" },
  { name = "commit", description = "Create git commit" },
  { name = "pr-coding-flow", description = "Create PR via coding-flow MCP" },
  { name = "refine", description = "Polish prose, preserve original language" },
  { name = "refine-en", description = "Polish prose in English" },
  { name = "repair", description = "Iterative repair workflow" },
  { name = "translate", description = "Bilingual translation" },
}

---@class ghc.cmp.slash
---@field protected _kind_event         integer
---@field protected _insert_format      integer
local M = {}

function M.new()
  local self = setmetatable({}, { __index = M })
  self._kind_event = require("blink.cmp.types").CompletionItemKind.Event
  self._insert_format = vim.lsp.protocol.InsertTextFormat.PlainText
  return self
end

function M:get_trigger_characters()
  return { "/" }
end

---Check if cursor is at a position where slash command completion should trigger
---@param context                       blink.cmp.Context
---@return boolean, lsp.Range|nil
function M:__should_complete__(context)
  local line = context.line ---@type string
  local col = context.cursor[2] ---@type integer

  -- Find the start of the current word
  local start_col = col ---@type integer
  while start_col > 0 do
    local char = line:sub(start_col, start_col)
    if char:match("[%s]") then
      break
    end
    start_col = start_col - 1
  end

  -- Check if the word starts with '/'
  local word_start = start_col + 1 ---@type integer
  if line:sub(word_start, word_start) ~= "/" then
    return false, nil
  end

  -- Only trigger at the beginning of a line or after whitespace
  if start_col > 0 then
    local prev_char = line:sub(start_col, start_col)
    if not prev_char:match("[%s]") then
      return false, nil
    end
  end

  ---@type lsp.Range
  local range = {
    start = { line = context.cursor[1] - 1, character = word_start - 1 },
    ["end"] = { line = context.cursor[1] - 1, character = col },
  }

  return true, range
end

---@param context                       blink.cmp.Context
---@param callback                      fun(response: blink.cmp.CompletionResponse): nil
function M:get_completions(context, callback)
  callback = vim.schedule_wrap(callback)

  local should_complete, range = self:__should_complete__(context)
  if not should_complete or not range then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  local items = {} ---@type lsp.CompletionItem[]

  for i, cmd in ipairs(commands) do
    local label = "/" .. cmd.name ---@type string
    local insert_text = "/" .. cmd.name .. " " ---@type string

    ---@type lsp.CompletionItem
    local item = {
      label = label,
      kind = self._kind_event,
      insertTextFormat = self._insert_format,
      insertText = insert_text,
      filterText = label,
      sortText = string.format("%03d", i),
      textEdit = {
        newText = insert_text,
        range = vim.deepcopy(range),
      },
      documentation = {
        kind = "plaintext",
        value = cmd.description,
      },
    }

    items[#items + 1] = item
  end

  callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = items })
end

---@param item                          lsp.CompletionItem
---@param callback                      fun(item: lsp.CompletionItem): nil
function M:resolve(item, callback)
  callback(item)
end

return M
