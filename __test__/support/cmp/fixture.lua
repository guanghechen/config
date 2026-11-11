---@diagnostic disable-next-line: unused-local
local __module_name__ = "__test__.support.cmp.fixture" ---@type string

-- Inputs of the in-process completion specs, which run over `__test__.support.cmp.runtime.setup()`. The benchmark
-- identifies its harness by the content of `runtime.lua`, so spec-only helpers live here.

local runtime = require("__test__.support.cmp.runtime")
local M = {}

---Shows `lines` in a new listed buffer of the current window, the only buffer `dot.tab.resolve` lists, until the case
---(or the suite, outside a case) ends.
---@param t                             __test__.support.Harness
---@param lines                         string[]
---@return integer
function M.buffer(t, lines)
  local bufnr = t:buffer(lines, { listed = true, current = true })
  t:patch_table(dot.tab, "resolve", function()
    return { bufs = { { bufnr = bufnr } } }
  end)
  return bufnr
end

---Base64 text of `size` characters from a fixed seed. Base64 has long runs of letters and digits; the image line of a
---Markdown file ends such a run with a parenthesis.
---@param size                          integer
---@return string
function M.base64(size)
  local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  local chars, seed = {}, 7 ---@type string[], integer
  for index = 1, size do
    seed = (seed * 1103515245 + 12345) % 2147483648
    local pick = seed % 64 + 1 ---@type integer
    chars[index] = alphabet:sub(pick, pick)
  end
  return table.concat(chars)
end

---Plans accepting the LSP item `raw` in a `filetype` buffer whose only line, the current buffer's, is `line` with the
---cursor at `col` (its end by default), then lets the bracket rules adjust the plan.
---@param filetype                      string
---@param line                          string
---@param col                           ?integer
---@param raw                           lsp.CompletionItem
---@return era.keystroke.cmp.IEditPlan
function M.bracket_plan(filetype, line, col, raw)
  local Edit = require("era.keystroke.cmp.edit")
  local Item = require("era.keystroke.cmp.item")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  local context = runtime.context(line, col)
  context.filetype = filetype
  local plan = assert(Edit.plan(assert(Item.new(context, "lsp", raw)), context))
  require("era.keystroke.cmp.brackets").prepare(context, raw, plan)
  return plan
end

return M
