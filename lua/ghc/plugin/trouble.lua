local icons = require("ghc.core.setting.icons")

return {
  "folke/trouble.nvim",
  cmd = { "TroubleToggle", "Trouble" },
  keys = {},
  opts = {
    position = "bottom", -- position of the list can be: bottom, top, left, right
    height = 20, -- height of the trouble list when position is top or bottom
    width = 50, -- width of the list when position is left or right
    icons = true, -- use devicons for filenames
    mode = "lsp_references", -- "workspace_diagnostics", "document_diagnostics", "quickfix", "lsp_references", "loclist"
    severity = vim.diagnostic.severity.WARN,
    fold_open = icons.ui.ArrowOpen, -- icon used for open folds
    fold_closed = icons.ui.ArrowClosed, -- icon used for closed folds
    use_diagnostic_signs = true,
    signs = {
      error = icons.diagnostics.Error_alt,
      warning = icons.diagnostics.Warning_alt,
      hint = icons.diagnostics.Hint_alt,
      information = icons.diagnostics.Information_alt,
      other = icons.diagnostics.Question_alt,
    },
  },
}
