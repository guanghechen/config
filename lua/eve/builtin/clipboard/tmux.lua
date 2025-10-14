---See https://neovim.io/doc/user/provider.html#clipboard-osc52

---@class eve.builtin.clipboard.tmux
local M = {}

function M.get_clipboard()
  return {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end

return M
