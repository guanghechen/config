local actions = require("ghc.command.search_files.actions")

---@type fml.types.IKeymap[]
local statusline_keymaps = {
  {
    modes = { "n", "v" },
    key = "<leader>1",
    callback = actions.toggle_scope,
    desc = "search: toggle scope",
  },
  {
    modes = { "n", "v" },
    key = "<leader>2",
    callback = actions.toggle_gitignore,
    desc = "search: toggle gitignore",
  },
  {
    modes = { "n", "v" },
    key = "<leader>3",
    callback = actions.toggle_regex,
    desc = "search: toggle regex",
  },
  {
    modes = { "n", "v" },
    key = "<leader>4",
    callback = actions.toggle_case_sensitive,
    desc = "search: toggle case sensitive",
  },
  {
    modes = { "n", "v" },
    key = "<leader>5",
    callback = actions.toggle_mode,
    desc = "search: toggle mode",
  },
  {
    modes = { "n", "v" },
    key = "<leader>W",
    callback = actions.change_scope_workspace,
    desc = "search: change scope (workspace)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>C",
    callback = actions.change_scope_cwd,
    desc = "search: change scope (cwd)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>D",
    callback = actions.change_scope_directory,
    desc = "search: change scope (directory)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>B",
    callback = actions.change_scope_buffer,
    desc = "search: change scope (buffer)",
  },
}

---@type fml.types.IKeymap[]
local common_keymaps = {
  {
    modes = { "n", "v" },
    key = "<leader>c",
    callback = actions.edit_config,
    desc = "search: edit config",
  },
}

---@type fml.types.IKeymap[]
local input_keymaps = {
  {
    modes = { "n", "v" },
    key = "<leader><cr>",
    callback = actions.replace_file,
    desc = "search: replace file",
  },
}

---@class ghc.command.search_files.keybindings
local M = {}

---@type fml.types.IKeymap[]
M.input_keymaps = fml.array.concat({}, statusline_keymaps, common_keymaps, input_keymaps)

---@type fml.types.IKeymap[]
M.main_keymaps = fml.array.concat({}, statusline_keymaps, common_keymaps, input_keymaps)

---@type fml.types.IKeymap[]
M.preview_keymaps = fml.array.concat({}, statusline_keymaps, common_keymaps)

return M
