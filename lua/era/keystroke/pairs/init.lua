---@diagnostic disable-next-line: unused-local
local __module_name__ = "era.keystroke.pairs" ---@type string

local Ops = require("era.keystroke.pairs.ops")
local Rule = require("era.keystroke.pairs.rule")

--- Typing pairs in Insert mode and on the command line: opening a pair closes it, typing its closing steps over it,
--- `<BS>` deletes it, and `<CR>` and `<Space>` open it up. The keys of a pair check the buffer's balance first.
---@class era.keystroke.pairs
local M = {}

local initialized = false ---@type boolean

---@return nil
function M.setup()
  if initialized then
    return
  end
  initialized = true

  local by_key, all = Rule.build()
  local insert = {} ---@type stl.t.IKeymap[]
  local cmdline = {} ---@type stl.t.IKeymap[]
  for key, rules in pairs(by_key) do
    local callback = Ops.on_key(key, rules)
    insert[#insert + 1] = { modes = { "i" }, key = key, desc = "pairs: " .. key, expr = true, callback = callback }
    cmdline[#cmdline + 1] = { modes = { "c" }, key = key, desc = "pairs: " .. key, expr = true, callback = callback }
  end
  local backspace = Ops.backspace(all)
  local space = Ops.space(all)
  vim.list_extend(insert, {
    { modes = { "i" }, key = "<BS>", desc = "pairs: delete a pair", expr = true, callback = backspace },
    { modes = { "i" }, key = "<CR>", desc = "pairs: open a pair over lines", expr = true, callback = Ops.enter(all) },
    { modes = { "i" }, key = "<Space>", desc = "pairs: pad a pair", expr = true, callback = space },
  })
  vim.list_extend(cmdline, {
    { modes = { "c" }, key = "<BS>", desc = "pairs: delete a pair", expr = true, callback = backspace },
    { modes = { "c" }, key = "<Space>", desc = "pairs: pad a pair", expr = true, callback = space },
  })
  stl.nvim.fn.bindkeys(insert, { silent = true, noremap = true })
  stl.nvim.fn.bindkeys(cmdline, { silent = false, noremap = true })
end

return M
