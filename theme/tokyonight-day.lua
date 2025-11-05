-- tokyonight-day

local config = {
  colors = {
    -- Primary colors
    background    = "#e1e2e7",
    foreground    = "#3760bf",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#9854f1",
    cursor_fg     = "#d0d5e3",
    cursor_border = "#9854f1",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#b7c1e3",
    selection_fg  = "#3760bf",

    -- Split separator color
    split         = "#1e3469",

    -- Scrollbar thumb color
    scrollbar_thumb = "#b7c1e3",

    -- Visual bell color
    visual_bell   = "#c4c8da",

    -- Compose cursor (for IME)
    compose_cursor = "#b15c00",

    -- Normal colors
    ansi = {
      "#e1e2e7",  -- black (surface1 for dark themes, subtext1 for latte)
      "#f52a65",
      "#587539",
      "#8c6c3e",
      "#2e7de9",
      "#7847bd",
      "#007197",
      "#3054a8",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#848cb5",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#c64343",
      "#387068",
      "#8c6c3e",
      "#188092",
      "#9854f1",
      "#118c74",
      "#294891",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#b15c00",
      [17] = "#9854f1",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#d0d5e3",

      active_tab = {
        bg_color = "#7847bd",
        fg_color = "#d0d5e3",
      },

      inactive_tab = {
        bg_color = "#d0d5e3",
        fg_color = "#3760bf",
      },

      inactive_tab_hover = {
        bg_color = "#e1e2e7",
        fg_color = "#3760bf",
      },

      new_tab = {
        bg_color = "#c4c8da",
        fg_color = "#3760bf",
      },

      new_tab_hover = {
        bg_color = "#c1c9df",
        fg_color = "#3760bf",
      },

      inactive_tab_edge = "#c4c8da",
    },
  },

  -- Window frame colors
  window_frame = {
    active_titlebar_bg = "#d0d5e3",
    active_titlebar_fg = "#3760bf",
    inactive_titlebar_bg = "#d0d5e3",
    inactive_titlebar_fg = "#3760bf",
    button_fg = "#3760bf",
    button_bg = "#e1e2e7",
  },

  -- Command palette colors
  command_palette_bg_color = "#d0d5e3",
  command_palette_fg_color = "#3760bf",
}

return config
