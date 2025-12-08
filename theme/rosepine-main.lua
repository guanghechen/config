-- rosepine-main

---@class theme.rosepine_main
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#191724",
    foreground    = "#E0DEF4",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#EB6F92",
    cursor_fg     = "#1F1D2E",
    cursor_border = "#EB6F92",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#524F67",
    selection_fg  = "#E0DEF4",

    -- Split separator color
    split         = "#6E6A86",

    -- Scrollbar thumb color
    scrollbar_thumb = "#524F67",

    -- Visual bell color
    visual_bell   = "#26233A",

    -- Compose cursor (for IME)
    compose_cursor = "#EBBCBA",

    -- Normal colors
    ansi = {
      "#191724",  -- black (surface1 for dark themes, subtext1 for latte)
      "#EB6F92",
      "#95B1AC",
      "#F6C177",
      "#31748F",
      "#C4A7E7",
      "#9CCFD8",
      "#E0DEF4",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#908CAA",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#EB6F92",
      "#95B1AC",
      "#F6C177",
      "#31748F",
      "#C4A7E7",
      "#9CCFD8",
      "#908CAA",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#EBBCBA",
      [17] = "#EB6F92",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#1F1D2E",

      active_tab = {
        bg_color = "#C4A7E7",
        fg_color = "#1F1D2E",
      },

      inactive_tab = {
        bg_color = "#1F1D2E",
        fg_color = "#E0DEF4",
      },

      inactive_tab_hover = {
        bg_color = "#191724",
        fg_color = "#E0DEF4",
      },

      new_tab = {
        bg_color = "#26233A",
        fg_color = "#E0DEF4",
      },

      new_tab_hover = {
        bg_color = "#403D52",
        fg_color = "#E0DEF4",
      },

      inactive_tab_edge = "#26233A",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#1F1D2E",
    active_titlebar_fg = "#E0DEF4",
    inactive_titlebar_bg = "#1F1D2E",
    inactive_titlebar_fg = "#E0DEF4",
    button_fg = "#E0DEF4",
    button_bg = "#191724",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#1F1D2E"
  config.command_palette_fg_color = "#E0DEF4"
end

return M
