---@class guanghechen.core.action.lsp
local M = {}

function M.codelens_run()
  vim.lsp.codelens.run()
end

function M.codelens_refresh()
  vim.lsp.codelens.refresh()
end

function M.goto_definitions()
  -- vim.lsp.buf.definition()
  require("telescope.builtin").lsp_definitions({
    initial_mode = "normal",
    reuse_win = false,
  })
  fml.api.state.update_state_when_buf_jump()
end

function M.goto_declarations()
  vim.lsp.buf.declaration()
  fml.api.state.update_state_when_buf_jump()
end

function M.goto_type_definitions()
  require("telescope.builtin").lsp_type_definitions({ reuse_win = false })
  fml.api.state.update_state_when_buf_jump()
end

function M.goto_implementations()
  require("telescope.builtin").lsp_implementations({ reuse_win = false })
  fml.api.state.update_state_when_buf_jump()
end

function M.hover()
  vim.lsp.buf.hover()
end

function M.rename()
  vim.lsp.buf.rename()
  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
end

function M.show_code_action()
  vim.lsp.buf.code_action()
  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
end

function M.show_code_action_source()
  vim.lsp.buf.code_action({
    context = {
      only = { "source" },
      diagnostics = {},
    },
  })
  vim.schedule(function()
    vim.cmd("stopinsert")
  end)
end

function M.show_references()
  require("telescope.builtin").lsp_references({ reuse_win = false })
end

function M.show_signature_help()
  vim.lsp.buf.signature_help()
end

return M
