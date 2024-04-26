-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

local statusline = require("ghc.ui.statusline")
local setting = {
  ui = require("ghc.setting.ui"),
}
local utils = {
  table = require("ghc.util.table"),
}

M.ui = {
  hl_add = vim.tbl_deep_extend("force", statusline.colors, {}),
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
  cmp = {
    icons = true,
    lspkind_text = true,
    style = "default", -- default/flat_light/flat_dark/atom/atom_colored
  },
  integration = {
    "blankline",
    "cmp",
    "git",
    "trouble",
  },
  statusline = {
    theme = "default", -- default / minimal / vscode / vscode_colored
    order = utils.table.merge_multiple_array(statusline.order_left, { "git", "%=", "diagnostics", "lsp" }, statusline.order_right),
    modules = vim.tbl_deep_extend("force", statusline.modules_left, statusline.modules_right),
  },
  tabufline = {
    enabled = true,
    lazyload = true,
    order = { "neotree", "buffers", "tabs", "btns" },
    modules = {
      neotree = function()
        local function getNeoTreeWidth()
          for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].ft == "neo-tree" then
              return vim.api.nvim_win_get_width(win) + 1
            end
          end
          return 0
        end
        local width = getNeoTreeWidth()
        if width > 0 then
          local word = "  Explorer"
          local left_width = math.floor((width - #word) / 2)
          local right_width = width - left_width - #word
          return "%#GHC_TABUFLINE_NEOTREE#" .. string.rep(" ", left_width) .. word .. string.rep(" ", right_width)
        else
          return ""
        end
      end,
    },
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
}

-- print(vim.inspect(M.ui))

return M
