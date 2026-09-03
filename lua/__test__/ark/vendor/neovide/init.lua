---@diagnostic disable: undefined-global

local harness = require("__test__.harness")

local t = harness.new("ark.vendor.neovide.init")

for _, module in ipairs({
  "dot.autocmd",
  "ark.vendor.neovide.option",
  "ark.vendor.neovide.keymap",
  "era.command",
  "era.plugin",
}) do
  t:patch_table(package.preload, module, function()
    return true
  end)
  t:patch_table(package.loaded, module, nil)
end

local cmp_count = 0
local function noop() end
local modules = {
  statusline = { dressing = noop },
  tabline = { dressing = noop },
  winline = { dressing = noop },
  commentstring = { dressing = noop },
  foldtext = { dressing = noop },
  scroll = { dressing = noop },
  statuscolumn = { dressing = noop },
  trailspace = { dressing = noop },
  virtcolumn = { dressing = noop },
  winsep = { dressing = noop },
  dim = { dressing = noop },
  cmp = {
    dressing = function()
      cmp_count = cmp_count + 1
    end,
  },
  im = { dressing = noop },
  input = { dressing = noop },
  lsp = { dressing = noop },
  select = { dressing = noop },
  image = { dressing = noop },
  wk = { dressing = noop },
  paste = { dressing = noop },
  surrounds = { setup = noop },
  notifier = { dressing = noop },
  ui_attach = { dressing = noop },
  git = { setup = noop },
}
t:patch_global("era", { m = modules })
t:patch_global("dot", {
  autocmd = {},
  path = {
    is_git_repo = function()
      return false
    end,
  },
  context = { watch_changes = noop },
  setup_context = noop,
  setup_diagnostics = noop,
})
t:patch_table(vim, "schedule", function(callback)
  callback()
end)
t:patch_table(package.loaded, "ark.vendor.neovide.init", nil)

t:test("initializes completion in the Neovide lifecycle", function()
  require("ark.vendor.neovide.init")
  t.assert_eq(1, cmp_count, "completion dressing")
end)

t:run()
