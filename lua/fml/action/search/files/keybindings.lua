local icons = require("eve.constant.icon")
local state = require("eve.state")

local context = require("fml.action.search.files.context")

---@type eve.t.ux.widget.IRawStatuslineItem[]
local statusline_items = {
  {
    type = "enum",
    desc = "search: toggle scope",
    symbol = "",
    state = state.select.search_file_scope,
    callback = context.toggle_scope,
  },
  {
    type = "flag",
    desc = "search: toggle gitignore",
    symbol = icons.symbols.flag_gitignore,
    state = state.select.search_file.flag_gitignore,
    callback = context.toggle_gitignore,
  },
  {
    type = "flag",
    desc = "search: toggle regex",
    symbol = icons.symbols.flag_regex,
    state = state.select.search_file.flag_regex,
    callback = context.toggle_regex,
  },
  {
    type = "flag",
    desc = "search: toggle case sensitive",
    symbol = icons.symbols.flag_case_sensitive,
    state = state.select.search_file.flag_case_sensitive,
    callback = context.toggle_case_sensitive,
  },
  {
    type = "flag",
    desc = "search: toggle mode",
    symbol = icons.symbols.flag_replace,
    state = state.search_file.flag_replace,
    callback = context.toggle_mode,
  },
}

---@type eve.t.IKeymap[]
local common_keymaps = {
  {
    modes = { "i", "n", "v" },
    key = "<C-q>",
    callback = context.send_to_qflist,
    desc = "search: send to qflist",
  },
  {
    modes = { "n", "v" },
    key = "<leader>tw",
    callback = context.change_scope_workspace,
    desc = "search: change scope (workspace)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>tc",
    callback = context.change_scope_cwd,
    desc = "search: change scope (cwd)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>td",
    callback = context.change_scope_directory,
    desc = "search: change scope (directory)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>tb",
    callback = context.change_scope_buffer,
    desc = "search: change scope (buffer)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>ts",
    callback = context.edit_config,
    desc = "search: edit config",
  },
  {
    modes = { "n", "v" },
    key = "<leader>ti",
    callback = context.toggle_case_sensitive,
    desc = "search: toggle case sensitive",
  },
  {
    modes = { "n", "v" },
    key = "<leader>tr",
    callback = context.toggle_regex,
    desc = "search: toggle regex",
  },
}

---@type eve.t.IKeymap[]
local input_keymaps = {
  {
    modes = { "n", "v" },
    key = "<C-a><cr>",
    aliases = { "<D-cr>", "<M-cr>" },
    callback = context.replace_file_all,
    desc = "search: replace all files",
    nowait = true,
  },
  {
    modes = { "n", "v" },
    key = "<leader><cr>",
    callback = context.replace_file,
    desc = "search: replace file",
    nowait = true,
  },
}

---@class fml.action.search.files.keybindings
local M = {}

---@type eve.t.ux.widget.IRawStatuslineItem[]
M.statusline_items = vim.list_slice(statusline_items)

---@type eve.t.IKeymap[]
M.input_keymaps = vim.list_extend(vim.list_slice(common_keymaps), input_keymaps)

---@type eve.t.IKeymap[]
M.main_keymaps = vim.list_extend(vim.list_slice(common_keymaps), input_keymaps)

---@type eve.t.IKeymap[]
M.preview_keymaps = vim.list_slice(common_keymaps)

return M
