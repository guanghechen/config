-- onehalf-dark

local config = {
  colors = {
    -- Primary colors
    background    = "#1E222A",
    foreground    = "#E5E9F0",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#DE8C92",
    cursor_fg     = "#252931",
    cursor_border = "#DE8C92",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#565C64",
    selection_fg  = "#E5E9F0",

    -- Split separator color
    split         = "#ABB2BF",

    -- Scrollbar thumb color
    scrollbar_thumb = "#565C64",

    -- Visual bell color
    visual_bell   = "#3E4451",

    -- Compose cursor (for IME)
    compose_cursor = "#D75F00",

    -- Normal colors
    ansi = {
      "#1E222A",  -- black (surface1 for dark themes, subtext1 for latte)
      "#E06C75",
      "#98C379",
      "#E5C07B",
      "#61AFEF",
      "#C678DD",
      "#56B6C2",
      "#D7DAE0",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#42464E",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#E06C75",
      "#7ECA9C",
      "#D19A66",
      "#61AFEF",
      "#B294BB",
      "#4EC9B0",
      "#C8CCD4",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#D75F00",
      [17] = "#DE8C92",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#252931",

      active_tab = {
        bg_color = "#C678DD",
        fg_color = "#252931",
      },

      inactive_tab = {
        bg_color = "#252931",
        fg_color = "#E5E9F0",
      },

      inactive_tab_hover = {
        bg_color = "#1E222A",
        fg_color = "#E5E9F0",
      },

      new_tab = {
        bg_color = "#3E4451",
        fg_color = "#E5E9F0",
      },

      new_tab_hover = {
        bg_color = "#545862",
        fg_color = "#E5E9F0",
      },

      inactive_tab_edge = "#3E4451",
    },
  },

  -- Window frame colors
  window_frame = {
    active_titlebar_bg = "#252931",
    active_titlebar_fg = "#E5E9F0",
    inactive_titlebar_bg = "#252931",
    inactive_titlebar_fg = "#E5E9F0",
    button_fg = "#E5E9F0",
    button_bg = "#1E222A",
  },

  -- Command palette colors
  command_palette_bg_color = "#252931",
  command_palette_fg_color = "#E5E9F0",
}

return config
