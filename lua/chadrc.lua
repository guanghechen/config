-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

local utils = {
  filetype = require("ghc.core.util.filetype"),
  path = require("ghc.core.util.path"), 
}

M.ui = {
  hl_add = {
    GHC_STATUSLINE_USERNAME = {
      fg = "#FFFFFF",
      bg = "#B57CA5",
    },
  },
  theme = "one_light",
  theme_toggle = { "onedark", "one_light" },
  transparency = true,
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
    order = { "username", "mode", "filepath", "git", "%=", "diagnostics", "lsp", "filetype", "cwd", "cursor" },
    modules = {
      username = function()
        local username = os.getenv("USER")
        return "%#GHC_STATUSLINE_USERNAME# " .. username .. " "
      end,
      cursor = function()
        return "%#St_pos_sep#%#St_pos_icon# %l·%c"
      end,
      filetype = function()
        local filepath = vim.fn.expand('%:p')
        local icon = utils.filetype.fileicon(filepath)
        local filetype = vim.bo.filetype
        return "%#St_file# " .. icon .. " " .. filetype
      end,
      filepath = function()
        local filepath = vim.fn.expand('%:p')
        local icon = utils.filetype.fileicon(filepath)
        local display_path = utils.path.relative(utils.path.cwd(), filepath)
        return "%#St_file# " .. icon .. " " .. display_path .. "%#St_file_sep#" .. ""
      end,
    },
  },
  tabufline = {
    enabled = true,
    lazyload = true,
    order = { "neo_tree", "buffers", "tabs", "btns" },
    modules = {
      neo_tree = function()
        local function getNeoTreeWidth()
          for _, win in pairs(vim.api.nvim_tabpage_list_wins(0)) do
            if vim.bo[vim.api.nvim_win_get_buf(win)].ft == "neo-tree" then
              return vim.api.nvim_win_get_width(win) + 1
            end
          end
          return 0
        end
        return "%#NvimTreeNormal#" .. string.rep(" ", getNeoTreeWidth())
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
