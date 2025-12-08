-- rosepine-moon

---@class theme.rosepine_moon
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background = "#232136",
    foreground = "#E0DEF4",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg = "#EB6F92",
    cursor_fg = "#2A273F",
    cursor_border = "#EB6F92",

    -- Selection colors (following official catppuccin theme)
    selection_bg = "#56526E",
    selection_fg = "#E0DEF4",

    -- Split separator color
    split = "#6E6A86",

    -- Scrollbar thumb color
    scrollbar_thumb = "#56526E",

    -- Visual bell color
    visual_bell = "#393552",

    -- Compose cursor (for IME)
    compose_cursor = "#EA9A97",

    -- Normal colors
    ansi = {
      "#232136", -- black (surface1 for dark themes, subtext1 for latte)
      "#EB6F92",
      "#95B1AC",
      "#F6C177",
      "#3E8FB0",
      "#C4A7E7",
      "#9CCFD8",
      "#E0DEF4", -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#908CAA", -- bright black (surface2 for dark themes, subtext0 for latte)
      "#EB6F92",
      "#95B1AC",
      "#F6C177",
      "#3E8FB0",
      "#C4A7E7",
      "#9CCFD8",
      "#908CAA", -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#EA9A97",
      [17] = "#EB6F92",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#2A273F",

      active_tab = {
        bg_color = "#C4A7E7",
        fg_color = "#2A273F",
      },

      inactive_tab = {
        bg_color = "#2A273F",
        fg_color = "#E0DEF4",
      },

      inactive_tab_hover = {
        bg_color = "#232136",
        fg_color = "#E0DEF4",
      },

      new_tab = {
        bg_color = "#393552",
        fg_color = "#E0DEF4",
      },

      new_tab_hover = {
        bg_color = "#44415A",
        fg_color = "#E0DEF4",
      },

      inactive_tab_edge = "#393552",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#2A273F",
    active_titlebar_fg = "#E0DEF4",
    inactive_titlebar_bg = "#2A273F",
    inactive_titlebar_fg = "#E0DEF4",
    button_fg = "#E0DEF4",
    button_bg = "#232136",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#2A273F"
  config.command_palette_fg_color = "#E0DEF4"
end

return M
