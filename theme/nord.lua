-- nord

---@class theme.nord
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background = "#2E3440",
    foreground = "#ECEFF4",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg = "#FFA3A3",
    cursor_fg = "#3B4252",
    cursor_border = "#FFA3A3",

    -- Selection colors (following official catppuccin theme)
    selection_bg = "#545862",
    selection_fg = "#ECEFF4",

    -- Split separator color
    split = "#B0BEC5",

    -- Scrollbar thumb color
    scrollbar_thumb = "#545862",

    -- Visual bell color
    visual_bell = "#434C5E",

    -- Compose cursor (for IME)
    compose_cursor = "#D08770",

    -- Normal colors
    ansi = {
      "#2E3440", -- black (surface1 for dark themes, subtext1 for latte)
      "#BF616A",
      "#A3BE8C",
      "#EBCB8B",
      "#5E81AC",
      "#B48EAD",
      "#88C0D0",
      "#E5E9F0", -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#4C566A", -- bright black (surface2 for dark themes, subtext0 for latte)
      "#BF616A",
      "#A3BE8C",
      "#EBCB8B",
      "#81A1C1",
      "#B48EAD",
      "#8FBCBB",
      "#D8DEE9", -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#D08770",
      [17] = "#FFA3A3",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#3B4252",

      active_tab = {
        bg_color = "#B48EAD",
        fg_color = "#3B4252",
      },

      inactive_tab = {
        bg_color = "#3B4252",
        fg_color = "#ECEFF4",
      },

      inactive_tab_hover = {
        bg_color = "#2E3440",
        fg_color = "#ECEFF4",
      },

      new_tab = {
        bg_color = "#434C5E",
        fg_color = "#ECEFF4",
      },

      new_tab_hover = {
        bg_color = "#4C566A",
        fg_color = "#ECEFF4",
      },

      inactive_tab_edge = "#434C5E",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#3B4252",
    active_titlebar_fg = "#ECEFF4",
    inactive_titlebar_bg = "#3B4252",
    inactive_titlebar_fg = "#ECEFF4",
    button_fg = "#ECEFF4",
    button_bg = "#2E3440",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#3B4252"
  config.command_palette_fg_color = "#ECEFF4"
end

return M
