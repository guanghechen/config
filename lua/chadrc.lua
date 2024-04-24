-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

local utils = {
  filetype = require("ghc.core.util.filetype"),
  path = require("ghc.core.util.path"),
  is_activewin = require("nvchad.stl.utils").is_activewin,
  modes = require("nvchad.stl.utils").modes,
  gen_with_modes_bg = function(prefix, fg)
    local function gen(modename, color)
      M.ui.hl_add[prefix .. "_" .. modename] = { fg = fg, bg = color }
    end

    gen("Normal", "nord_blue")
    gen("Visual", "cyan")
    gen("Insert", "dark_purple")
    gen("Terminal", "green")
    gen("NTerminal", "yellow")
    gen("Replace", "orange")
    gen("Confirm", "teal")
    gen("Command", "green")
    gen("Select", "blue")
  end,
}

local symbols = {
  separator = { left = "", right = "" },
}

M.ui = {
  hl_add = {
    GHC_STATUSLINE_USERNAME = {
      fg = "#FFFFFF",
      bg = "baby_pink",
    },
    GHC_TABUFLINE_NEOTREE = {
      fg = "white",
      bg = "black2",
    },
  },
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
    order = {
      "customized_username",
      "customized_mode",
      "customized_filepath",
      "git",
      "%=",
      "diagnostics",
      "lsp",
      "customized_filetype",
      "cwd",
      "customized_cursor",
    },
    modules = {
      customized_cursor = function()
        return "%#St_pos_sep#%#St_pos_icon# %l·%c"
      end,
      customized_filetype = function()
        local filepath = vim.fn.expand("%:p")
        local icon = utils.filetype.fileicon(filepath)
        local filetype = vim.bo.filetype
        return "%#St_file# " .. icon .. " " .. filetype .. " "
      end,
      customized_filepath = function()
        local filepath = vim.fn.expand("%:p")
        local icon = utils.filetype.fileicon(filepath)
        local display_path = utils.path.relative(utils.path.cwd(), filepath)
        return "%#St_file# " .. icon .. " " .. display_path .. "%#St_file_sep#" .. symbols.separator.right
      end,
      customized_mode = function()
        if not utils.is_activewin() then
          return ""
        end

        local modes = utils.modes
        local m = vim.api.nvim_get_mode().mode
        local color_mode = "%#St_" .. modes[m][2] .. "Mode#"
        local color_ghc_statusline_username_separator = "%#GHC_STATUS_USERNAME_SEPARATOR" .. "_" .. modes[m][2] .. "#"
        local current_mode = color_ghc_statusline_username_separator .. symbols.separator.right .. color_mode .. " " .. modes[m][1] .. " "
        local mode_sep1 = "%#St_" .. modes[m][2] .. "ModeSep#" .. symbols.separator.right
        return current_mode .. mode_sep1 .. "%#ST_EmptySpace#" .. symbols.separator.right
      end,
      customized_username = function()
        local username = os.getenv("USER")
        return "%#GHC_STATUSLINE_USERNAME# " .. username .. " "
      end,
    },
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
          local word = "neo-tree"
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

-- gen colors with mode
utils.gen_with_modes_bg("GHC_STATUS_USERNAME_SEPARATOR", "baby_pink") -- gen separator colors.

return M
