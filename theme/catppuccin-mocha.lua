-- catppuccin-mocha

---@class theme.catppuccin_mocha
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#1E1E2E",
    foreground    = "#CDD6F4",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#F5E0DC",
    cursor_fg     = "#11111B",
    cursor_border = "#F5E0DC",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#585B70",
    selection_fg  = "#CDD6F4",

    -- Split separator color
    split         = "#6C7086",

    -- Scrollbar thumb color
    scrollbar_thumb = "#585B70",

    -- Visual bell color
    visual_bell   = "#313244",

    -- Compose cursor (for IME)
    compose_cursor = "#F2CDCD",

    -- Normal colors
    ansi = {
      "#45475A",  -- black (surface1 for dark themes, subtext1 for latte)
      "#F38BA8",
      "#A6E3A1",
      "#F9E2AF",
      "#89B4FA",
      "#F5C2E7",
      "#94E2D5",
      "#BAC2DE",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#585B70",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#F38BA8",
      "#A6E3A1",
      "#F9E2AF",
      "#89B4FA",
      "#F5C2E7",
      "#94E2D5",
      "#A6ADC8",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#FAB387",
      [17] = "#F5E0DC",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#11111B",

      active_tab = {
        bg_color = "#CBA6F7",
        fg_color = "#11111B",
      },

      inactive_tab = {
        bg_color = "#181825",
        fg_color = "#CDD6F4",
      },

      inactive_tab_hover = {
        bg_color = "#1E1E2E",
        fg_color = "#CDD6F4",
      },

      new_tab = {
        bg_color = "#313244",
        fg_color = "#CDD6F4",
      },

      new_tab_hover = {
        bg_color = "#45475A",
        fg_color = "#CDD6F4",
      },

      inactive_tab_edge = "#313244",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#11111B",
    active_titlebar_fg = "#CDD6F4",
    inactive_titlebar_bg = "#11111B",
    inactive_titlebar_fg = "#CDD6F4",
    button_fg = "#CDD6F4",
    button_bg = "#1E1E2E",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#11111B"
  config.command_palette_fg_color = "#CDD6F4"
end

return M
