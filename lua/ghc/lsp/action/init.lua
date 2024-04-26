local actions = {
  codelens_run = function()
    vim.lsp.codelens.run()
  end,
  codelens_refresh = function()
    vim.lsp.codelens.refresh()
  end,
  goto_definitions = function()
    -- vim.lsp.buf.definition()
    require("telescope.builtin").lsp_definitions({ reuse_win = true })
  end,
  goto_declarations = function()
    vim.lsp.buf.declaration()
  end,
  goto_type_definitions = function()
    require("telescope.builtin").lsp_type_definitions({ reuse_win = true })
  end,
  goto_implementations = function()
    require("telescope.builtin").lsp_implementations({ reuse_win = true })
  end,
  hover = function()
    vim.lsp.buf.hover()
  end,
  rename = function()
    -- vim.lsp.buf.rename()
    require("ghc.lsp.action.rename")()
  end,
  show_code_action = function()
    vim.lsp.buf.code_action()
  end,
  show_code_action_source = function()
    vim.lsp.buf.code_action({
      context = {
        only = {
          "source",
        },
        diagnostics = {},
      },
    })
  end,
  show_references = function()
    require("telescope.builtin").lsp_references({ reuse_win = true })
  end,
  show_signature_help = function()
    vim.lsp.buf.signature_help()
  end,
}

return actions
