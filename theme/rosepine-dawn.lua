-- rosepine-dawn

---@class theme.rosepine_dawn
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#FAF4ED",
    foreground    = "#464261",

    -- Cursor colors
    cursor_bg     = "#464261",
    cursor_fg     = "#FAF4ED",
    cursor_border = "#464261",

    -- Selection colors
    selection_bg  = "#DFDAD9",
    selection_fg  = "#464261",

    -- Split separator color
    split         = "#CECACD",

    -- Scrollbar thumb color
    scrollbar_thumb = "#CECACD",

    -- Visual bell color
    visual_bell   = "#F2E9E1",

    -- Compose cursor (for IME)
    compose_cursor = "#D7827E",

    -- Normal colors
    ansi = {
      "#F2E9E1",
      "#B4637A",
      "#286983",
      "#EA9D34",
      "#56949F",
      "#907AA9",
      "#D7827E",
      "#464261",
    },

    -- Bright colors
    brights = {
      "#9893A5",
      "#B4637A",
      "#286983",
      "#EA9D34",
      "#56949F",
      "#907AA9",
      "#D7827E",
      "#464261",
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#D7827E",
      [17] = "#B4637A",
    },

    -- Tab bar colors
    tab_bar = {
      background = "#FFFAF3",

      active_tab = {
        bg_color = "#F2E9E1",
        fg_color = "#464261",
      },

      inactive_tab = {
        bg_color = "#FAF4ED",
        fg_color = "#9893A5",
      },

      inactive_tab_hover = {
        bg_color = "#FFFAF3",
        fg_color = "#464261",
      },

      new_tab = {
        bg_color = "#FFFAF3",
        fg_color = "#9893A5",
      },

      new_tab_hover = {
        bg_color = "#F2E9E1",
        fg_color = "#464261",
      },

      inactive_tab_edge = "#DFDAD9",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#FFFAF3",
    active_titlebar_fg = "#464261",
    inactive_titlebar_bg = "#FFFAF3",
    inactive_titlebar_fg = "#9893A5",
    button_fg = "#464261",
    button_bg = "#FAF4ED",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#FFFAF3"
  config.command_palette_fg_color = "#464261"
end

return M
