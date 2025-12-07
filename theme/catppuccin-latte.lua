-- catppuccin-latte

---@class theme.catppuccin_latte
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#EFF1F5",
    foreground    = "#4C4F69",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#DC8A78",
    cursor_fg     = "#DCE0E8",
    cursor_border = "#DC8A78",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#ACB0BE",
    selection_fg  = "#4C4F69",

    -- Split separator color
    split         = "#9CA0B0",

    -- Scrollbar thumb color
    scrollbar_thumb = "#ACB0BE",

    -- Visual bell color
    visual_bell   = "#CCD0DA",

    -- Compose cursor (for IME)
    compose_cursor = "#DD7878",

    -- Normal colors
    ansi = {
      "#BCC0CC",  -- black (surface1 for dark themes, subtext1 for latte)
      "#D20F39",
      "#40A02B",
      "#DF8E1D",
      "#1E66F5",
      "#EA76CB",
      "#179299",
      "#5C5F77",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#ACB0BE",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#D20F39",
      "#40A02B",
      "#DF8E1D",
      "#1E66F5",
      "#EA76CB",
      "#179299",
      "#6C6F85",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#FE640B",
      [17] = "#DC8A78",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#DCE0E8",

      active_tab = {
        bg_color = "#8839EF",
        fg_color = "#DCE0E8",
      },

      inactive_tab = {
        bg_color = "#E6E9EF",
        fg_color = "#4C4F69",
      },

      inactive_tab_hover = {
        bg_color = "#EFF1F5",
        fg_color = "#4C4F69",
      },

      new_tab = {
        bg_color = "#CCD0DA",
        fg_color = "#4C4F69",
      },

      new_tab_hover = {
        bg_color = "#BCC0CC",
        fg_color = "#4C4F69",
      },

      inactive_tab_edge = "#CCD0DA",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#DCE0E8",
    active_titlebar_fg = "#4C4F69",
    inactive_titlebar_bg = "#DCE0E8",
    inactive_titlebar_fg = "#4C4F69",
    button_fg = "#4C4F69",
    button_bg = "#EFF1F5",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#DCE0E8"
  config.command_palette_fg_color = "#4C4F69"
end

return M
