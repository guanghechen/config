-- tokyonight-storm

---@class theme.tokyonight_storm
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#24283b",
    foreground    = "#c0caf5",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#bb9af7",
    cursor_fg     = "#1f2335",
    cursor_border = "#bb9af7",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#2e3c64",
    selection_fg  = "#c0caf5",

    -- Split separator color
    split         = "#707aa4",

    -- Scrollbar thumb color
    scrollbar_thumb = "#2e3c64",

    -- Visual bell color
    visual_bell   = "#1b1e2d",

    -- Compose cursor (for IME)
    compose_cursor = "#ff9e64",

    -- Normal colors
    ansi = {
      "#24283b",  -- black (surface1 for dark themes, subtext1 for latte)
      "#f7768e",
      "#9ece6a",
      "#e0af68",
      "#7aa2f7",
      "#9d7cd8",
      "#7dcfff",
      "#adb7e2",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#565f89",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#db4b4b",
      "#73daca",
      "#e0af68",
      "#2ac3de",
      "#bb9af7",
      "#1abc9c",
      "#9ba5cf",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#ff9e64",
      [17] = "#bb9af7",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#1f2335",

      active_tab = {
        bg_color = "#9d7cd8",
        fg_color = "#1f2335",
      },

      inactive_tab = {
        bg_color = "#1f2335",
        fg_color = "#c0caf5",
      },

      inactive_tab_hover = {
        bg_color = "#24283b",
        fg_color = "#c0caf5",
      },

      new_tab = {
        bg_color = "#1b1e2d",
        fg_color = "#c0caf5",
      },

      new_tab_hover = {
        bg_color = "#292e42",
        fg_color = "#c0caf5",
      },

      inactive_tab_edge = "#1b1e2d",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#1f2335",
    active_titlebar_fg = "#c0caf5",
    inactive_titlebar_bg = "#1f2335",
    inactive_titlebar_fg = "#c0caf5",
    button_fg = "#c0caf5",
    button_bg = "#24283b",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#1f2335"
  config.command_palette_fg_color = "#c0caf5"
end

return M
