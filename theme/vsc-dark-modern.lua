-- vsc-dark-modern

---@class theme.vsc_dark_modern
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#1F1F1F",
    foreground    = "#FFFFFF",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#F5A9B8",
    cursor_fg     = "#202020",
    cursor_border = "#F5A9B8",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#454545",
    selection_fg  = "#FFFFFF",

    -- Split separator color
    split         = "#6E7681",

    -- Scrollbar thumb color
    scrollbar_thumb = "#454545",

    -- Visual bell color
    visual_bell   = "#313131",

    -- Compose cursor (for IME)
    compose_cursor = "#CE9178",

    -- Normal colors
    ansi = {
      "#1F1F1F",  -- black (surface1 for dark themes, subtext1 for latte)
      "#F85149",
      "#2EA043",
      "#DCDCAA",
      "#0078D4",
      "#C586C0",
      "#4EC9B0",
      "#CCCCCC",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#707070",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#F85149",
      "#B5CEA8",
      "#DCDCAA",
      "#9CDCFE",
      "#C586C0",
      "#4FC1FF",
      "#9D9D9D",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#CE9178",
      [17] = "#F5A9B8",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#202020",

      active_tab = {
        bg_color = "#C586C0",
        fg_color = "#202020",
      },

      inactive_tab = {
        bg_color = "#202020",
        fg_color = "#FFFFFF",
      },

      inactive_tab_hover = {
        bg_color = "#1F1F1F",
        fg_color = "#FFFFFF",
      },

      new_tab = {
        bg_color = "#313131",
        fg_color = "#FFFFFF",
      },

      new_tab_hover = {
        bg_color = "#3C3C3C",
        fg_color = "#FFFFFF",
      },

      inactive_tab_edge = "#313131",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#202020",
    active_titlebar_fg = "#FFFFFF",
    inactive_titlebar_bg = "#202020",
    inactive_titlebar_fg = "#FFFFFF",
    button_fg = "#FFFFFF",
    button_bg = "#1F1F1F",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#202020"
  config.command_palette_fg_color = "#FFFFFF"
end

return M
