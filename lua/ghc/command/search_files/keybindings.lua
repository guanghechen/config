local session = require("ghc.context.session")
local actions = require("ghc.command.search_files.actions")

---@type eve.types.ux.widgets.IRawStatuslineItem[]
local statusline_items = {
  {
    type = "enum",
    desc = "search: toggle scope",
    symbol = "",
    state = session.search_scope,
    callback = actions.toggle_scope,
  },
  {
    type = "flag",
    desc = "search: toggle gitignore",
    symbol = eve.icons.symbols.flag_gitignore,
    state = session.search_flag_gitignore,
    callback = actions.toggle_gitignore,
  },
  {
    type = "flag",
    desc = "search: toggle regex",
    symbol = eve.icons.symbols.flag_regex,
    state = session.search_flag_regex,
    callback = actions.toggle_regex,
  },
  {
    type = "flag",
    desc = "search: toggle case sensitive",
    symbol = eve.icons.symbols.flag_case_sensitive,
    state = session.search_flag_case_sensitive,
    callback = actions.toggle_case_sensitive,
  },
  {
    type = "flag",
    desc = "search: toggle mode",
    symbol = eve.icons.symbols.flag_replace,
    state = session.search_flag_replace,
    callback = actions.toggle_mode,
  },
}

---@type eve.types.ux.IKeymap[]
local common_keymaps = {
  {
    modes = { "i", "n", "v" },
    key = "<C-q>",
    callback = actions.send_to_qflist,
    desc = "search: send to qflist",
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
  {
    modes = { "n", "v" },
    key = "<leader>c",
    callback = actions.edit_config,
    desc = "search: edit config",
  },
  {
    modes = { "n", "v" },
    key = "<leader>i",
    callback = actions.toggle_case_sensitive,
    desc = "search: toggle case sensitive",
  },
  {
    modes = { "n", "v" },
    key = "<leader>r",
    callback = actions.toggle_regex,
    desc = "search: toggle regex",
  },
}

---@type eve.types.ux.IKeymap[]
local input_keymaps = {
  {
    modes = { "n", "v" },
    key = "<leader><enter>",
    callback = actions.replace_file,
    desc = "search: replace file",
    nowait = true,
  },
  {
    modes = { "n", "v" },
    key = "<leader><S-enter>",
    callback = actions.replace_file_all,
    desc = "search: replace all files",
    nowait = true,
  },
}

---@class ghc.command.search_files.keybindings
local M = {}

---@type eve.types.ux.widgets.IRawStatuslineItem[]
M.statusline_items = eve.array.concat({}, statusline_items)

---@type eve.types.ux.IKeymap[]
M.input_keymaps = eve.array.concat({}, common_keymaps, input_keymaps)

---@type eve.types.ux.IKeymap[]
M.main_keymaps = eve.array.concat({}, common_keymaps, input_keymaps)

---@type eve.types.ux.IKeymap[]
M.preview_keymaps = eve.array.concat({}, common_keymaps)

return M
