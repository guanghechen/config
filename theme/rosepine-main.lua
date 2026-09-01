-- rosepine-main

---@class theme.rosepine_main
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#191724",
    foreground    = "#E0DEF4",

    -- Cursor colors
    cursor_bg     = "#E0DEF4",
    cursor_fg     = "#191724",
    cursor_border = "#E0DEF4",

    -- Selection colors
    selection_bg  = "#403D52",
    selection_fg  = "#E0DEF4",

    -- Split separator color
    split         = "#524F67",

    -- Scrollbar thumb color
    scrollbar_thumb = "#524F67",

    -- Visual bell color
    visual_bell   = "#26233A",

    -- Compose cursor (for IME)
    compose_cursor = "#EBBCBA",

    -- Normal colors
    ansi = {
      "#26233A",
      "#EB6F92",
      "#31748F",
      "#F6C177",
      "#9CCFD8",
      "#C4A7E7",
      "#EBBCBA",
      "#E0DEF4",
    },

    -- Bright colors
    brights = {
      "#6E6A86",
      "#EB6F92",
      "#31748F",
      "#F6C177",
      "#9CCFD8",
      "#C4A7E7",
      "#EBBCBA",
      "#E0DEF4",
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#EBBCBA",
      [17] = "#EB6F92",
    },

    -- Tab bar colors
    tab_bar = {
      background = "#1F1D2E",

      active_tab = {
        bg_color = "#26233A",
        fg_color = "#E0DEF4",
      },

      inactive_tab = {
        bg_color = "#191724",
        fg_color = "#6E6A86",
      },

      inactive_tab_hover = {
        bg_color = "#1F1D2E",
        fg_color = "#E0DEF4",
      },

      new_tab = {
        bg_color = "#1F1D2E",
        fg_color = "#6E6A86",
      },

      new_tab_hover = {
        bg_color = "#26233A",
        fg_color = "#E0DEF4",
      },

      inactive_tab_edge = "#403D52",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#1F1D2E",
    active_titlebar_fg = "#E0DEF4",
    inactive_titlebar_bg = "#1F1D2E",
    inactive_titlebar_fg = "#6E6A86",
    button_fg = "#E0DEF4",
    button_bg = "#191724",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#1F1D2E"
  config.command_palette_fg_color = "#E0DEF4"
end

return M
