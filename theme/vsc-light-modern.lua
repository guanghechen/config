-- vsc-light-modern

local config = {
  colors = {
    -- Primary colors
    background    = "#FFFFFF",
    foreground    = "#1F1F1F",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#E75480",
    cursor_fg     = "#F8F8F8",
    cursor_border = "#E75480",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#E5E5E5",
    selection_fg  = "#1F1F1F",

    -- Split separator color
    split         = "#767676",

    -- Scrollbar thumb color
    scrollbar_thumb = "#E5E5E5",

    -- Visual bell color
    visual_bell   = "#F2F2F2",

    -- Compose cursor (for IME)
    compose_cursor = "#C72E0F",

    -- Normal colors
    ansi = {
      "#FFFFFF",  -- black (surface1 for dark themes, subtext1 for latte)
      "#F85149",
      "#2EA043",
      "#795E26",
      "#005FB8",
      "#AF00DB",
      "#267F99",
      "#3B3B3B",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#767676",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#F85149",
      "#098658",
      "#795E26",
      "#001080",
      "#AF00DB",
      "#0070C1",
      "#616161",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#C72E0F",
      [17] = "#E75480",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#F8F8F8",

      active_tab = {
        bg_color = "#AF00DB",
        fg_color = "#F8F8F8",
      },

      inactive_tab = {
        bg_color = "#F8F8F8",
        fg_color = "#1F1F1F",
      },

      inactive_tab_hover = {
        bg_color = "#FFFFFF",
        fg_color = "#1F1F1F",
      },

      new_tab = {
        bg_color = "#F2F2F2",
        fg_color = "#1F1F1F",
      },

      new_tab_hover = {
        bg_color = "#E5E5E5",
        fg_color = "#1F1F1F",
      },

      inactive_tab_edge = "#F2F2F2",
    },
  },

  -- Window frame colors
  window_frame = {
    active_titlebar_bg = "#F8F8F8",
    active_titlebar_fg = "#1F1F1F",
    inactive_titlebar_bg = "#F8F8F8",
    inactive_titlebar_fg = "#1F1F1F",
    button_fg = "#1F1F1F",
    button_bg = "#FFFFFF",
  },

  -- Command palette colors
  command_palette_bg_color = "#F8F8F8",
  command_palette_fg_color = "#1F1F1F",
}

return config
