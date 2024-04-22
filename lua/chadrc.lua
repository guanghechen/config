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
        vim.notify("neo-tree-width: " .. getNeoTreeWidth())
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
