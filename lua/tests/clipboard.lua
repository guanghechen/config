local clipboard = require("guanghechen.util.clipboard")
vim.notify(vim.inspect(clipboard.get_clipboard()))

local tmux = require("guanghechen.util.tmux")
local fake_clipboard_filepath = tmux.get_tmux_env_value("ghc_use_fake_clipboard")
vim.notify(vim.inspect(fake_clipboard_filepath))
