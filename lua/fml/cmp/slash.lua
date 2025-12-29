---@class fml.cmp.slash.ICommand
---@field public name                   string
---@field public description            string

---@type fml.cmp.slash.ICommand[]
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

---@class fml.cmp.slash
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

  -- Find the '/' character by scanning backward
  local slash_col = col ---@type integer
  while slash_col > 0 do
    local char = line:sub(slash_col, slash_col)
    if char == "/" then
      break
    elseif char:match("[%s%p]") then
      -- Stop at whitespace or punctuation without finding '/'
      return false, nil
    end
    slash_col = slash_col - 1
  end

  -- No '/' found
  if slash_col == 0 or line:sub(slash_col, slash_col) ~= "/" then
    return false, nil
  end

  -- Check if '/' is at line start or preceded by whitespace/punctuation
  if slash_col > 1 then
    local prev_char = line:sub(slash_col - 1, slash_col - 1)
    if not prev_char:match("[%s%p]") then
      return false, nil
    end
  end

  ---@type lsp.Range
  local range = {
    start = { line = context.cursor[1] - 1, character = slash_col - 1 },
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
