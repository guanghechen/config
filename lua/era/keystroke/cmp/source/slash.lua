---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.cmp.source.slash" ---@type string

local Item = require("era.keystroke.cmp.item")
local M = {}
local commands = {
  { "code-analyze", "Perform comprehensive code review on target" },
  { "code-analyze-followup", "Follow-up analysis after fixes" },
  { "code-apply", "Apply fixes from previous analysis" },
  { "code-fix-lsp", "Fix LSP diagnostics errors" },
  { "code-impl", "Execute coding task" },
  { "code-review", "Review code changes or verify fixes" },
  { "commit", "Create git commit" },
  { "pr-coding-flow", "Create PR via coding-flow MCP" },
  { "refine", "Polish prose, preserve original language" },
  { "refine-en", "Polish prose in English" },
  { "repair", "Iterative repair workflow" },
  { "translate", "Bilingual translation" },
}

---@param context                       era.keystroke.cmp.IContext
---@param callback                      fun(response: era.keystroke.cmp.IResponse): nil
---@return nil
function M.complete(context, callback)
  local prefix = context.line:sub(1, context.col)
  local start = prefix:match("()/[%w_-]*$")
  local items = {} ---@type era.keystroke.cmp.IItem[]
  if start ~= nil and (start == 1 or prefix:sub(start - 1, start - 1):match("[%s%p]")) then
    for index, command in ipairs(commands) do
      local label = "/" .. command[1]
      local item = Item.new(context, "slash", {
        label = label,
        kind = vim.lsp.protocol.CompletionItemKind.Event,
        sortText = string.format("%03d", index),
        textEdit = Item.text_edit(context, start - 1, label .. " "),
        documentation = { kind = "plaintext", value = command[2] },
      })
      items[#items + 1] = item
    end
  end
  callback({ items = items, incomplete = false })
end

return M
