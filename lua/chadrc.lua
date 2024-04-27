-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

local bufferline = require("ghc.ui.bufferline")
local statusline = require("ghc.ui.statusline")
local setting = {
  ui = require("ghc.core.setting.ui"),
}
local util = {
  table = require("ghc.core.util.table"),
}

M.ui = {
  hl_add = vim.tbl_deep_extend("force", bufferline.colors, statusline.colors, {}),
  hl_override = {
    CursorLine = {
      bg = "one_bg2", -- "line"
    },
    Comment = {
      italic = true,
    },
  },
  theme = "onedark",
  theme_toggle = { "onedark", "one_light" },
  transparency = setting.ui.transparency,
  base46 = {
    integration = {
      "blankline",
      "cmp",
      "git",
      "trouble",
    },
  },
  statusline = {
    theme = "default", -- default / minimal / vscode / vscode_colored
    separator_style = "default",
    order = util.table.merge_multiple_array(statusline.order_left, { "git", "%=", "diagnostics", "lsp" }, statusline.order_right),
    modules = vim.tbl_deep_extend("force", statusline.modules_left, statusline.modules_right),
  },
  tabufline = {
    enabled = true,
    lazyload = true,
    order = util.table.merge_multiple_array(bufferline.order_left, { "buffers", "tabs", "btns" }, bufferline.order_right),
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

-- print(vim.inspect(M.ui))

return M
