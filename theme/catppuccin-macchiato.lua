-- catppuccin-macchiato

local config = {
  colors = {
    -- Primary colors
    background    = "#24273A",
    foreground    = "#CAD3F5",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#F4DBD6",
    cursor_fg     = "#181926",
    cursor_border = "#F4DBD6",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#5B6078",
    selection_fg  = "#CAD3F5",

    -- Split separator color
    split         = "#6E738D",

    -- Scrollbar thumb color
    scrollbar_thumb = "#5B6078",

    -- Visual bell color
    visual_bell   = "#363A4F",

    -- Compose cursor (for IME)
    compose_cursor = "#F0C6C6",

    -- Normal colors
    ansi = {
      "#494D64",  -- black (surface1 for dark themes, subtext1 for latte)
      "#ED8796",
      "#A6DA95",
      "#EED49F",
      "#8AADF4",
      "#F5BDE6",
      "#8BD5CA",
      "#B8C0E0",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#5B6078",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#ED8796",
      "#A6DA95",
      "#EED49F",
      "#8AADF4",
      "#F5BDE6",
      "#8BD5CA",
      "#A5ADCB",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#F5A97F",
      [17] = "#F4DBD6",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#181926",

      active_tab = {
        bg_color = "#C6A0F6",
        fg_color = "#181926",
      },

      inactive_tab = {
        bg_color = "#1E2030",
        fg_color = "#CAD3F5",
      },

      inactive_tab_hover = {
        bg_color = "#24273A",
        fg_color = "#CAD3F5",
      },

      new_tab = {
        bg_color = "#363A4F",
        fg_color = "#CAD3F5",
      },

      new_tab_hover = {
        bg_color = "#494D64",
        fg_color = "#CAD3F5",
      },

      inactive_tab_edge = "#363A4F",
    },
  },

  -- Window frame colors
  window_frame = {
    active_titlebar_bg = "#181926",
    active_titlebar_fg = "#CAD3F5",
    inactive_titlebar_bg = "#181926",
    inactive_titlebar_fg = "#CAD3F5",
    button_fg = "#CAD3F5",
    button_bg = "#24273A",
  },

  -- Command palette colors
  command_palette_bg_color = "#181926",
  command_palette_fg_color = "#CAD3F5",
}

return config
