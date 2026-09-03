---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.m.cmp.source.slash" ---@type string

local util = require("era.m.cmp.source.util")

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

local M = {}

---@param context                       era.m.cmp.IContext
---@return lsp.CompletionItem[]
function M.complete(context)
  local before = context.line:sub(1, context.col) ---@type string
  local query = before:match("/([%w%-]*)$") ---@type string|nil
  if query == nil then
    return {}
  end

  local start_col = context.col - #query - 1 ---@type integer
  if start_col > 0 and not context.line:sub(start_col, start_col):match("%s") then
    return {}
  end
  local items = {} ---@type lsp.CompletionItem[]
  for index, command in ipairs(commands) do
    local label = "/" .. command.name ---@type string
    items[#items + 1] = util.item("slash", 220, {
      label = label,
      kind = vim.lsp.protocol.CompletionItemKind.Event,
      filterText = label,
      sortText = string.format("%03d", index),
      documentation = { kind = "plaintext", value = command.description },
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.PlainText,
      textEdit = {
        newText = label .. " ",
        range = util.range(context, start_col, context.end_col),
      },
    }, "slash\0" .. label)
  end
  return util.filter("/" .. query, items)
end

return M
