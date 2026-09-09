require("dot.autocmd")
pcall(require, "ark.vendor.local.autocmd")

dot.setup_context()
require("ark.vendor.neovim.option")
require("ark.vendor.neovim.keymap")
pcall(require, "ark.vendor.local.option")
pcall(require, "ark.vendor.local.keymap")

era.dressing.setup({
  "notifier",
  "ui_attach",
  "im",
})
require("era.command")

if dot.path.is_git_repo() then
  era.m.git.setup()
end

require("era.plugin")
pcall(require, "ark.vendor.local.plugin")

vim.schedule(function()
  era.dressing.setup({
    -- Status and navigation lines.
    "statusline",
    "tabline",
    "winline",

    -- Gutter, whitespace, and window guides.
    "statuscolumn",
    "trailspace",
    "virtcolumn",
    "winsep",

    -- Buffer syntax and structure.
    "commentstring",
    "foldtext",
    "hipattern",
    "indentline",
    "indentscope",
    "whichkey",

    -- Scrolling behavior.
    "scroll",
  })

  era.m.dim.dressing()
  era.m.input.dressing()
  era.m.lsp.dressing()
  era.m.select.dressing()
  era.m.image.dressing()
  era.m.paste.dressing()
  era.m.splitjoin.setup()
  era.m.surrounds.setup()
  era.m.textobject.setup()

  pcall(require, "ark.vendor.local.dressing")

  dot.setup_diagnostics()
  dot.context.watch_changes()
end)
