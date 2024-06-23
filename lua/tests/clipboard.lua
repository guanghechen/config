local clipboard = require("guanghechen.util.clipboard")
vim.notify(vim.inspect(clipboard.get_clipboard()))

local fake_clipboard_filepath = fml.tmux.get_tmux_env_value("ghc_use_fake_clipboard")
vim.notify(vim.inspect(fake_clipboard_filepath))
