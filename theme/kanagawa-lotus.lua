-- kanagawa-lotus

---@class theme.kanagawa_lotus
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#F2ECBC",
    foreground    = "#545464",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#B35B79",
    cursor_fg     = "#E7DBA0",
    cursor_border = "#B35B79",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#B5CBD2",
    selection_fg  = "#545464",

    -- Split separator color
    split         = "#A09CAC",

    -- Scrollbar thumb color
    scrollbar_thumb = "#B5CBD2",

    -- Visual bell color
    visual_bell   = "#E4D794",

    -- Compose cursor (for IME)
    compose_cursor = "#CC6D00",

    -- Normal colors
    ansi = {
      "#F2ECBC",  -- black (surface1 for dark themes, subtext1 for latte)
      "#C84053",
      "#6F894E",
      "#77713F",
      "#4D699B",
      "#B35B79",
      "#597B75",
      "#43436C",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#8A8980",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#D7474B",
      "#6E915F",
      "#836F4A",
      "#6693BF",
      "#624C83",
      "#5E857A",
      "#716E61",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#CC6D00",
      [17] = "#B35B79",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#E7DBA0",

      active_tab = {
        bg_color = "#B35B79",
        fg_color = "#E7DBA0",
      },

      inactive_tab = {
        bg_color = "#E7DBA0",
        fg_color = "#545464",
      },

      inactive_tab_hover = {
        bg_color = "#F2ECBC",
        fg_color = "#545464",
      },

      new_tab = {
        bg_color = "#E4D794",
        fg_color = "#545464",
      },

      new_tab_hover = {
        bg_color = "#C9CBD1",
        fg_color = "#545464",
      },

      inactive_tab_edge = "#E4D794",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#E7DBA0",
    active_titlebar_fg = "#545464",
    inactive_titlebar_bg = "#E7DBA0",
    inactive_titlebar_fg = "#545464",
    button_fg = "#545464",
    button_bg = "#F2ECBC",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#E7DBA0"
  config.command_palette_fg_color = "#545464"
end

return M
