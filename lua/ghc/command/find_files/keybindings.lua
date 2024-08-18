local session = require("ghc.context.session")
local actions = require("ghc.command.find_files.actions")

---@type fml.types.ui.search.IRawStatuslineItem[]
local statusline_items = {
  {
    type = "enum",
    desc = "find: toggle scope",
    symbol = "",
    state = session.find_scope,
    callback = actions.toggle_scope,
  },
  {
    type = "flag",
    desc = "find: toggle gitignore",
    symbol = fml.ui.icons.symbols.flag_gitignore,
    state = session.find_flag_gitignore,
    callback = actions.toggle_gitignore,
  },
  {
    type = "flag",
    desc = "find: toggle case sensitive",
    symbol = fml.ui.icons.symbols.flag_case_sensitive,
    state = session.find_flag_case_sensitive,
    callback = actions.toggle_case_sensitive,
  },
}

---@type fml.types.IKeymap[]
local common_keymaps = {
  {
    modes = { "n", "v" },
    key = "<leader>W",
    callback = actions.change_scope_workspace,
    desc = "find: change scope (workspace)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>C",
    callback = actions.change_scope_cwd,
    desc = "find: change scope (cwd)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>D",
    callback = actions.change_scope_directory,
    desc = "find: change scope (directory)",
  },
  {
    modes = { "n", "v" },
    key = "<leader>c",
    callback = actions.edit_config,
    desc = "find: edit config",
  },
}

---@class ghc.command.find_files.keybindings
local M = {}

---@type fml.types.ui.search.IRawStatuslineItem[]
M.statusline_items = fml.array.concat({}, statusline_items)

---@type fml.types.IKeymap[]
M.input_keymaps = fml.array.concat({}, common_keymaps)

---@type fml.types.IKeymap[]
M.main_keymaps = fml.array.concat({}, common_keymaps)

---@type fml.types.IKeymap[]
M.preview_keymaps = fml.array.concat({}, common_keymaps)

return M
