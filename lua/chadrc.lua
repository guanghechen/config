-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

local context_config = require("ghc.core.context.config")
local util_table = require("guanghechen.util.table")

---@type boolean
local transparency = context_config.transparency:get_snapshot()

local bufferline = require("ghc.ui.bufferline")
local statusline = require("ghc.ui.statusline")
local theme_integrations = require("ghc.ui.theme.integration")

---@type ChadrcConfig
local M = {}

M.ui = {
  hl_add = vim.tbl_deep_extend("force", bufferline.colors, statusline.colors, theme_integrations, {
    FlashBackdrop = {
      fg = "grey_fg",
      bg = "none",
      italic = true,
    },
    FlashCursor = {
      fg = "red",
      bg = transparency and "none" or "grey",
    },
    FlashLabel = {
      fg = "white",
      bg = transparency and "none" or "grey",
    },
    FlashMatch = {
      fg = "cyan",
      bg = transparency and "none" or "grey",
    },
  }),
  hl_override = {
    CursorLine = {
      bg = "one_bg2", -- "line"
    },
    Comment = {
      -- italic = true,
    },
    Visual = {
      bg = "light_grey",
    },
  },
  theme = context_config.get_current_theme(),
  theme_toggle = {},
  transparency = context_config.transparency:get_snapshot(),
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
    order = util_table.merge_multiple_array(statusline.order_left, { "%=" }, statusline.order_middle, { "%=" }, statusline.order_right),
    modules = vim.tbl_deep_extend("force", statusline.modules_left, statusline.modules_middle, statusline.modules_right),
  },
  tabufline = {
    enabled = true,
    lazyload = true,
    order = util_table.merge_multiple_array(bufferline.order_left, { "buffers", "tabs" }, bufferline.order_right),
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

return M
