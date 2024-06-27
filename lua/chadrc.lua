-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

local bufferline = require("guanghechen.ui.bufferline")

---@type ChadrcConfig
local M = {}

local current_theme = ghc.context.shared.mode:get_snapshot() == "darken" and "onedark" or "one_light" ---@type string

M.ui = {
  theme = current_theme,
  theme_toggle = {},
  transparency = ghc.context.shared.transparency:get_snapshot(),
  base46 = {
    integration = {
      "blankline",
      "cmp",
      "git",
      "notify",
      "trouble",
    },
  },
  statusline = {
    theme = "default", -- default / minimal / vscode / vscode_colored
    separator_style = "default",
    order = {},
    modules = {}
  },
  tabufline = {
    enabled = true,
    lazyload = true,
    order = fml.table.merge_multiple_array(bufferline.order_left, { "buffers", "tabs" }, bufferline.order_right),
    modules = vim.tbl_deep_extend("force", bufferline.modules_left, bufferline.modules_right),
  },
  telescope = {
    style = "borderless",
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
  },
  lsp = { signature = true },
  cmp = {
    icons = true,
    lspkind_text = true,
    style = "default", -- default/flat_light/flat_dark/atom/atom_colored
  },
  cheatsheet = { theme = "grid" }, -- simple/grid
}

--print(vim.inspect(M.ui))
--ghc.context.shared.reload_theme({ force = false })

return M
