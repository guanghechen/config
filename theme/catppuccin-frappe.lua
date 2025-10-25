-- catppuccin-frappe

local config = {
  colors = {
    -- Primary colors
    background    = "#303446",
    foreground    = "#C6D0F5",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#F2D5CF",
    cursor_fg     = "#232634",
    cursor_border = "#F2D5CF",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#626880",
    selection_fg  = "#C6D0F5",

    -- Split separator color
    split         = "#737994",

    -- Scrollbar thumb color
    scrollbar_thumb = "#626880",

    -- Visual bell color
    visual_bell   = "#414559",

    -- Compose cursor (for IME)
    compose_cursor = "#EEBEBE",

    -- Normal colors
    ansi = {
      "#51576D",  -- black (surface1 for dark themes, subtext1 for latte)
      "#E78284",
      "#A6D189",
      "#E5C890",
      "#8CAAEE",
      "#F4B8E4",
      "#81C8BE",
      "#B5BFE2",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#626880",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#E78284",
      "#A6D189",
      "#E5C890",
      "#8CAAEE",
      "#F4B8E4",
      "#81C8BE",
      "#A5ADCE",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#EF9F76",
      [17] = "#F2D5CF",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#232634",

      active_tab = {
        bg_color = "#CA9EE6",
        fg_color = "#232634",
      },

      inactive_tab = {
        bg_color = "#292C3C",
        fg_color = "#C6D0F5",
      },

      inactive_tab_hover = {
        bg_color = "#303446",
        fg_color = "#C6D0F5",
      },

      new_tab = {
        bg_color = "#414559",
        fg_color = "#C6D0F5",
      },

      new_tab_hover = {
        bg_color = "#51576D",
        fg_color = "#C6D0F5",
      },

      inactive_tab_edge = "#414559",
    },
  },

  -- Window frame colors
  window_frame = {
    active_titlebar_bg = "#232634",
    active_titlebar_fg = "#C6D0F5",
    inactive_titlebar_bg = "#232634",
    inactive_titlebar_fg = "#C6D0F5",
    button_fg = "#C6D0F5",
    button_bg = "#303446",
  },

  -- Command palette colors
  command_palette_bg_color = "#232634",
  command_palette_fg_color = "#C6D0F5",
}

return config
