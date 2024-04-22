-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

M.ui = {
  theme = "onedark",
  theme_toggle = { "onedark", "one_light" },
  transparency = true,
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
  telescope = {
    style = "borderless"
  },
  term = {
    hl = "Normal:term,WinSeparator:WinSeparator",
    sizes = { sp = 0.3, vsp = 0.2 },
    float = {
      -- {row,col} indicate the left-top corner.
      row = 0.08,
      col = 0.1,

      -- {width,height} indicate the width and height of the floating window.
      width = 0.8,
      height = 0.8,
      relative = "editor",
      border = "single",
    },
  },
  nvdash = {
    load_on_startup = false,
    header = {},
    buttons = {},
  }
}

return M
