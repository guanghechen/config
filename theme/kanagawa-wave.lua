-- kanagawa-wave

---@class theme.kanagawa_wave
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#1F1F28",
    foreground    = "#DCD7BA",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#D27E99",
    cursor_fg     = "#2A2A37",
    cursor_border = "#D27E99",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#2D4F67",
    selection_fg  = "#DCD7BA",

    -- Split separator color
    split         = "#727169",

    -- Scrollbar thumb color
    scrollbar_thumb = "#2D4F67",

    -- Visual bell color
    visual_bell   = "#363646",

    -- Compose cursor (for IME)
    compose_cursor = "#FFA066",

    -- Normal colors
    ansi = {
      "#1F1F28",  -- black (surface1 for dark themes, subtext1 for latte)
      "#C34043",
      "#76946A",
      "#C0A36E",
      "#7E9CD8",
      "#957FB8",
      "#6A9589",
      "#C8C093",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#727169",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#E82424",
      "#98BB6C",
      "#E6C384",
      "#7FB4CA",
      "#938AA9",
      "#7AA89F",
      "#9CABCA",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#FFA066",
      [17] = "#D27E99",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#2A2A37",

      active_tab = {
        bg_color = "#957FB8",
        fg_color = "#2A2A37",
      },

      inactive_tab = {
        bg_color = "#2A2A37",
        fg_color = "#DCD7BA",
      },

      inactive_tab_hover = {
        bg_color = "#1F1F28",
        fg_color = "#DCD7BA",
      },

      new_tab = {
        bg_color = "#363646",
        fg_color = "#DCD7BA",
      },

      new_tab_hover = {
        bg_color = "#223249",
        fg_color = "#DCD7BA",
      },

      inactive_tab_edge = "#363646",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#2A2A37",
    active_titlebar_fg = "#DCD7BA",
    inactive_titlebar_bg = "#2A2A37",
    inactive_titlebar_fg = "#DCD7BA",
    button_fg = "#DCD7BA",
    button_bg = "#1F1F28",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#2A2A37"
  config.command_palette_fg_color = "#DCD7BA"
end

return M
