-- vsc-dark-modern

local config = {
  colors = {
    -- Primary colors
    background    = "#1F1F1F",
    foreground    = "#CCCCCC",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#CE9178",
    cursor_fg     = "#181818",
    cursor_border = "#CE9178",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#313131",
    selection_fg  = "#CCCCCC",

    -- Split separator color
    split         = "#6E7681",

    -- Scrollbar thumb color
    scrollbar_thumb = "#313131",

    -- Visual bell color
    visual_bell   = "#202020",

    -- Compose cursor (for IME)
    compose_cursor = "#CE9178",

    -- Normal colors
    ansi = {
      "#1F1F1F",  -- black (surface1 for dark themes, subtext1 for latte)
      "#F85149",
      "#2EA043",
      "#DCDCAA",
      "#0078D4",
      "#C586C0",
      "#4EC9B0",
      "#D7D7D7",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#9D9D9D",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#F85149",
      "#B5CEA8",
      "#DCDCAA",
      "#9CDCFE",
      "#C586C0",
      "#4FC1FF",
      "#9D9D9D",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#CE9178",
      [17] = "#CE9178",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#181818",

      active_tab = {
        bg_color = "#C586C0",
        fg_color = "#181818",
      },

      inactive_tab = {
        bg_color = "#181818",
        fg_color = "#CCCCCC",
      },

      inactive_tab_hover = {
        bg_color = "#1F1F1F",
        fg_color = "#CCCCCC",
      },

      new_tab = {
        bg_color = "#202020",
        fg_color = "#CCCCCC",
      },

      new_tab_hover = {
        bg_color = "#2B2B2B",
        fg_color = "#CCCCCC",
      },

      inactive_tab_edge = "#202020",
    },
  },

  -- Window frame colors
  window_frame = {
    active_titlebar_bg = "#181818",
    active_titlebar_fg = "#CCCCCC",
    inactive_titlebar_bg = "#181818",
    inactive_titlebar_fg = "#CCCCCC",
    button_fg = "#CCCCCC",
    button_bg = "#1F1F1F",
  },

  -- Command palette colors
  command_palette_bg_color = "#181818",
  command_palette_fg_color = "#CCCCCC",
}

return config
