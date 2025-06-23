---@class eve.builtin.setting
local M = {}

M.feedkeys = {
  UNDO = vim.api.nvim_replace_termcodes("<C-G>u", true, true, true),
}

---@class eve.builtin.setting.ai_providers
M.ai_providers = {
  "aoai",
  "azuredatabricks",
  "copilot",
  "deepseek",
}

---@class eve.builtin.setting.themes
M.themes = {
  "catppuccin-frappe",
  "catppuccin-latte",
  "catppuccin-macchiato",
  "catppuccin-mocha",
  "gruvbox-dark",
  "gruvbox-light",
  "nord",
  "one-half-dark",
  "one-half-light",
  "rose-pine-main",
  "rose-pine-moon",
  "rose-pine-dawn",
}

---@class eve.builtin.setting.togglers
M.togglers = {
  "auto_im_behavior",
  "bufs_relative_behavior",

  "fileencoding_local",
  "fileformat_local",
  "hipatterns_local",
  "markdown_local",
  "relativenumber_local",
  "wrap_local",

  "notification_paused_ux",
  "relativenumber_ux",
  "transparency_ux",
  "theme_ux",
  "theme_variant_ux",
  "username_ux",

  "ai_flight",
  "ai_provider_flight",
  "autoformat_flight",
  "autoload_flight",
  "autosave_flight",
  "devmode_flight",
  "dressing_clipboard_flight",
  "dressing_hipairs_flight",
  "dressing_illumniate_flight",
  "dressing_input_flight",
  "dressing_select_flight",
  "dressing_winsep_flight",
  "gitdiff_expand_all_flight",

  "code_lens_lsp",
  "diagnostics_virt_lines_lsp",
  "inlay_hints_lsp",
  "python_debug_host_lsp",
  "python_debug_port_lsp",
  "python_venv_lsp",
  "spellcheck_lsp",

  "render_markdown_plugin",
  "treesitter_context_plugin",

  "maximize",
}

---@class eve.builtin.setting.sessions
M.sessions = {
  persistent_options = table.concat({
    "blank",
    "buffers",
    "curdir",
    "folds",
    "globals",
    "help",
    "resize",
    "slash",
    "skiprtp",
    "tabpages",
    "unix",
    "winpos",
    "winsize",
  }, ","),
}

---! Window settings

M.WIN_HISTORY_CAPACITY = 99
M.WIN_BUF_HISTORY_CAPACITY = 99

---! Buffer settings

M.BUF_UNTITLED = "untitled"

---! Special symbols.

M.EDITING_INPUT_PREFIX = "@#!eve!#@"

return M
