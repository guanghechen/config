-- This file  needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/NvChad/blob/v2.5/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

local base_30 = {
  white = "#abb2bf",
  darker_black = "#1b1f27",
  black = "#1e222a", --  nvim bg
  black2 = "#252931",
  one_bg = "#282c34", -- real bg of onedark
  one_bg2 = "#353b45",
  one_bg3 = "#373b43",
  grey = "#42464e",
  grey_fg = "#565c64",
  grey_fg2 = "#6f737b",
  light_grey = "#6f737b",
  red = "#e06c75",
  baby_pink = "#DE8C92",
  pink = "#ff75a0",
  line = "#31353d", -- for lines like vertsplit
  green = "#98c379",
  vibrant_green = "#7eca9c",
  nord_blue = "#81A1C1",
  blue = "#61afef",
  yellow = "#e7c787",
  sun = "#EBCB8B",
  purple = "#de98fd",
  dark_purple = "#c882e7",
  teal = "#519ABA",
  orange = "#fca2aa",
  cyan = "#a3b8ef",
  statusline_bg = "#22262e",
  lightbg = "#2d3139",
  pmenu_bg = "#61afef",
  folder_bg = "#61afef",
}

local utils = {
  filetype = require("ghc.core.util.filetype"),
  path = require("ghc.core.util.path"),
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
local settings = {
  modes = require("nvchad.stl.utils").modes,
  symbols = {
    ui = require("ghc.core.icons").get("ui"),
    separator = {
      left = "",
      right = "",
    },
  },
  transparency = true,
}
settings.flags = {
  has_cwd = function()
    return vim.o.columns > 85
  end,
  has_filepath = function()
    local filepath = vim.fn.expand("%:p")
    if not filepath or #filepath == 0 then
      return false
    end

    local relative_path = utils.path.relative(utils.path.cwd(), filepath)
    return relative_path ~= "."
  end,
  has_filetype = function()
    local filetype = vim.bo.filetype
    return filetype and #filetype > 0
  end,
  has_mode = function()
    return require("nvchad.stl.utils").is_activewin()
  end,
  is_cwd_leftest = function()
    return not settings.flags.has_filetype()
  end,
  is_filetype_leftest = function()
    return true
  end,
  is_pos_leftest = function()
    return not settings.flags.has_filetype() and not settings.flags.has_cwd()
  end,
}

M.ui = {
  hl_add = {
    GHC_STATUSLINE_CWD_ICON = {
      fg = "black",
      bg = "vibrant_green",
    },
    GHC_STATUSLINE_CWD_TEXT = {
      fg = "white",
      bg = settings.transparency and "none" or "statusline_bg",
    },
    GHC_STATUSLINE_CWD_SEPARATOR = {
      fg = "vibrant_green",
      bg = "lightbg",
    },
    GHC_STATUSLINE_CWD_SEPARATOR_LEFTEST = {
      fg = "vibrant_green",
      bg = settings.transparency and "none" or "statusline_bg",
    },
    GHC_STATUSLINE_FILETYPE_ICON = {
      fg = "black",
      bg = "red",
    },
    GHC_STATUSLINE_FILETYPE_TEXT = {
      fg = "white",
      bg = settings.transparency and "none" or "statusline_bg",
    },
    GHC_STATUSLINE_FILETYPE_SEPARATOR = {
      fg = "red",
      bg = "lightbg",
    },
    GHC_STATUSLINE_FILETYPE_SEPARATOR_LEFTEST = {
      fg = "red",
      bg = settings.transparency and "none" or "statusline_bg",
    },
    GHC_STATUSLINE_POS_ICON = {
      fg = "black",
      bg = "green",
    },
    GHC_STATUSLINE_POS_TEXT = {
      fg = "black",
      bg = "green",
    },
    GHC_STATUSLINE_POS_SEPARATOR = {
      fg = "green",
      bg = "lightbg",
    },
    GHC_STATUSLINE_POS_SEPARATOR_LEFTEST = {
      fg = "green",
      bg = settings.transparency and "none" or "statusline_bg",
    },
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
  transparency = settings.transparency,
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
      "customized_cwd",
      "customized_pos",
    },
    modules = {
      customized_cwd = function()
        if not settings.flags.has_cwd() then
          return ""
        end

        local name = vim.loop.cwd()

        local separator = "%#GHC_STATUSLINE_CWD_SEPARATOR"
          .. (settings.flags.is_cwd_leftest() and "_LEFTEST" or "")
          .. "#"
          .. settings.symbols.separator.left
        local icon = "%#GHC_STATUSLINE_CWD_ICON#" .. "󰉋 "
        local text = "%#GHC_STATUSLINE_CWD_TEXT# " .. (name:match("([^/\\]+)[/\\]*$") or name) .. " "
        return separator .. icon .. text
      end,
      customized_filetype = function()
        if not settings.flags.has_filetype() then
          return ""
        end

        local filetype = vim.bo.filetype
        local filepath = vim.fn.expand("%:p")

        local separator = "%#GHC_STATUSLINE_FILETYPE_SEPARATOR"
          .. (settings.flags.is_filetype_leftest() and "_LEFTEST" or "")
          .. "#"
          .. settings.symbols.separator.left
        local icon = "%#GHC_STATUSLINE_FILETYPE_ICON#" .. utils.filetype.fileicon(filepath)
        local text = " %#GHC_STATUSLINE_FILETYPE_TEXT# " .. filetype .. " "
        return separator .. icon .. text
      end,
      customized_filepath = function()
        if not settings.flags.has_filepath() then
          return ""
        end

        local filepath = vim.fn.expand("%:p")
        local relative_path = utils.path.relative(utils.path.cwd(), filepath)

        local icon = "%#St_file# " .. utils.filetype.fileicon(filepath)
        local text = " " .. relative_path .. " "
        local separator = "%#St_file_sep#" .. settings.symbols.separator.right
        return icon .. text .. separator
      end,
      customized_mode = function()
        if not settings.flags.has_mode() then
          return ""
        end

        local modes = settings.modes
        local m = vim.api.nvim_get_mode().mode
        local color_mode = "%#St_" .. modes[m][2] .. "Mode#"
        local color_ghc_statusline_username_separator = "%#GHC_STATUS_USERNAME_SEPARATOR" .. "_" .. modes[m][2] .. "#"
        local current_mode = color_ghc_statusline_username_separator
          .. settings.symbols.separator.right
          .. color_mode
          .. " "
          .. modes[m][1]
          .. " "
        local mode_sep1 = "%#St_" .. modes[m][2] .. "ModeSep#" .. settings.symbols.separator.right
        return current_mode .. mode_sep1 .. "%#ST_EmptySpace#" .. settings.symbols.separator.right
      end,
      customized_pos = function()
        local separator = "%#GHC_STATUSLINE_POS_SEPARATOR"
          .. (settings.flags.is_pos_leftest() and "_LEFTEST" or "")
          .. "#"
          .. settings.symbols.separator.left
        local icon = "%#GHC_STATUSLINE_POS_ICON#" .. " "
        local text = "%#GHC_STATUSLINE_POS_TEXT#" .. "%l·%c "
        return separator .. icon .. text
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
          local word = settings.symbols.ui.Explorer .. " Explorer"
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
