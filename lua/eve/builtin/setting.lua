---@class eve.builtin.setting
local M = {}

M.feedkeys = {
  UNDO = vim.api.nvim_replace_termcodes("<C-G>u", true, true, true),
}

---@class eve.builtin.setting.ai_providers
M.ai_providers = {
  "copilot",
  "deepseek",
  "aoai",
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
}

---@class eve.builtin.setting.togglers
M.togglers = {
  "ai_flight",
  "ai_provider_flight",
  "autoformat_flight",
  "autoload_flight",
  "autosave_flight",
  "devmode_flight",
  "dressing_hipairs_flight",
  "dressing_illumniate_flight",
  "dressing_input_flight",
  "dressing_select_flight",
  "dressing_winsep_fixed_flight",
  "dressing_winsep_float_flight",
  "gitdiff_expand_all_flight",
  "fileformat_local",
  "hipatterns_local",
  "markdown_local",
  "relativenumber_local",
  "wrap_local",
  "code_lens_lsp",
  "inlay_hints_lsp",
  "python_debug_host_lsp",
  "python_debug_port_lsp",
  "python_venv_lsp",
  "spellcheck_lsp",
  "render_markdown_plugin",
  "smear_cursor_plugin",
  "treesitter_context_plugin",
  "theme_theme",
  "theme_variant_theme",
  "relativenumber_ux",
  "transparency_ux",
  "username_ux",
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

---! Tab settings

M.TAB_HISTORY_CAPACITY = 100

---! Window settings

M.WIN_HISTORY_CAPACITY = 99
M.WIN_BUF_HISTORY_CAPACITY = 99

---! Buffer settings

M.BUF_UNTITLED = "untitled"

---! Special symbols.

M.EDITING_INPUT_PREFIX = "@#!eve!#@"

return M
