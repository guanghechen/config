-- tokyonight-moon

local config = {
  colors = {
    -- Primary colors
    background    = "#222436",
    foreground    = "#c8d3f5",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#c099ff",
    cursor_fg     = "#1e2030",
    cursor_border = "#c099ff",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#2d3f76",
    selection_fg  = "#c8d3f5",

    -- Split separator color
    split         = "#7c86ba",

    -- Scrollbar thumb color
    scrollbar_thumb = "#2d3f76",

    -- Visual bell color
    visual_bell   = "#191b29",

    -- Compose cursor (for IME)
    compose_cursor = "#ff966c",

    -- Normal colors
    ansi = {
      "#222436",  -- black (surface1 for dark themes, subtext1 for latte)
      "#ff757f",
      "#c3e88d",
      "#ffc777",
      "#82aaff",
      "#fca7ea",
      "#86e1fc",
      "#b6c1e7",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#636da6",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#c53b53",
      "#4fd6be",
      "#ffc777",
      "#65bcff",
      "#c099ff",
      "#4fd6be",
      "#a5afd9",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#ff966c",
      [17] = "#c099ff",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#1e2030",

      active_tab = {
        bg_color = "#fca7ea",
        fg_color = "#1e2030",
      },

      inactive_tab = {
        bg_color = "#1e2030",
        fg_color = "#c8d3f5",
      },

      inactive_tab_hover = {
        bg_color = "#222436",
        fg_color = "#c8d3f5",
      },

      new_tab = {
        bg_color = "#191b29",
        fg_color = "#c8d3f5",
      },

      new_tab_hover = {
        bg_color = "#2f334d",
        fg_color = "#c8d3f5",
      },

      inactive_tab_edge = "#191b29",
    },
  },

  -- Window frame colors
  window_frame = {
    active_titlebar_bg = "#1e2030",
    active_titlebar_fg = "#c8d3f5",
    inactive_titlebar_bg = "#1e2030",
    inactive_titlebar_fg = "#c8d3f5",
    button_fg = "#c8d3f5",
    button_bg = "#222436",
  },

  -- Command palette colors
  command_palette_bg_color = "#1e2030",
  command_palette_fg_color = "#c8d3f5",
}

return config
