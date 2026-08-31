-- rosepine-dawn

---@class theme.rosepine_dawn
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#FAF4ED",
    foreground    = "#464261",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#B4637A",
    cursor_fg     = "#FFFAF3",
    cursor_border = "#B4637A",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#CECACD",
    selection_fg  = "#464261",

    -- Split separator color
    split         = "#9893A5",

    -- Scrollbar thumb color
    scrollbar_thumb = "#CECACD",

    -- Visual bell color
    visual_bell   = "#F2E9E1",

    -- Compose cursor (for IME)
    compose_cursor = "#D7827E",

    -- Normal colors
    ansi = {
      "#FAF4ED",  -- black (surface1 for dark themes, subtext1 for latte)
      "#B4637A",
      "#286983",
      "#EA9D34",
      "#56949F",
      "#907AA9",
      "#D7827E",
      "#464261",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#9893A5",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#B4637A",
      "#286983",
      "#EA9D34",
      "#56949F",
      "#907AA9",
      "#D7827E",
      "#797593",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#D7827E",
      [17] = "#B4637A",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#FFFAF3",

      active_tab = {
        bg_color = "#907AA9",
        fg_color = "#FFFAF3",
      },

      inactive_tab = {
        bg_color = "#FFFAF3",
        fg_color = "#464261",
      },

      inactive_tab_hover = {
        bg_color = "#FAF4ED",
        fg_color = "#464261",
      },

      new_tab = {
        bg_color = "#F2E9E1",
        fg_color = "#464261",
      },

      new_tab_hover = {
        bg_color = "#DFDAD9",
        fg_color = "#464261",
      },

      inactive_tab_edge = "#F2E9E1",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#FFFAF3",
    active_titlebar_fg = "#464261",
    inactive_titlebar_bg = "#FFFAF3",
    inactive_titlebar_fg = "#464261",
    button_fg = "#464261",
    button_bg = "#FAF4ED",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#FFFAF3"
  config.command_palette_fg_color = "#464261"
end

return M
