-- kanagawa-dragon

---@class theme.kanagawa_dragon
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#181616",
    foreground    = "#C5C9C5",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#A292A3",
    cursor_fg     = "#282727",
    cursor_border = "#A292A3",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#2D4F67",
    selection_fg  = "#C5C9C5",

    -- Split separator color
    split         = "#737C73",

    -- Scrollbar thumb color
    scrollbar_thumb = "#2D4F67",

    -- Visual bell color
    visual_bell   = "#393836",

    -- Compose cursor (for IME)
    compose_cursor = "#B6927B",

    -- Normal colors
    ansi = {
      "#181616",  -- black (surface1 for dark themes, subtext1 for latte)
      "#C4746E",
      "#8A9A7B",
      "#C4B28A",
      "#8BA4B0",
      "#A292A3",
      "#8EA4A2",
      "#C8C093",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#A6A69C",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#E46876",
      "#87A987",
      "#E6C384",
      "#7FB4CA",
      "#938AA9",
      "#7AA89F",
      "#A6A69C",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#B6927B",
      [17] = "#A292A3",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#282727",

      active_tab = {
        bg_color = "#A292A3",
        fg_color = "#282727",
      },

      inactive_tab = {
        bg_color = "#282727",
        fg_color = "#C5C9C5",
      },

      inactive_tab_hover = {
        bg_color = "#181616",
        fg_color = "#C5C9C5",
      },

      new_tab = {
        bg_color = "#393836",
        fg_color = "#C5C9C5",
      },

      new_tab_hover = {
        bg_color = "#223249",
        fg_color = "#C5C9C5",
      },

      inactive_tab_edge = "#393836",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#282727",
    active_titlebar_fg = "#C5C9C5",
    inactive_titlebar_bg = "#282727",
    inactive_titlebar_fg = "#C5C9C5",
    button_fg = "#C5C9C5",
    button_bg = "#181616",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#282727"
  config.command_palette_fg_color = "#C5C9C5"
end

return M
