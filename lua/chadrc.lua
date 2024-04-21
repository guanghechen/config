-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

M.ui = {
  theme = "onedark",
  integration = {
    "blankline",
    "cmp",
    "git",
  },
  statusline = {
    theme = "default", -- default / minimal / vscode / vscode_colored
    order = { "username", "mode", "file", "git", "%=", "diagnostics", "lsp", "filetype", "cwd", "cursor" },
    modules = {
      username = function()
        local username = os.getenv("USER")
        return "%#GHC_USERNAME# " .. username .. " "
      end,
      cursor = function()
        return "%#St_pos_sep#%#St_pos_icon# %l·%c"
      end,
      filetype = function()
        return vim.bo.filetype
      end,
    },
  },
}

return M
