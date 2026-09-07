-- rosepine-moon

---@class theme.rosepine_moon
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#232136",
    foreground    = "#E0DEF4",

    -- Cursor colors
    cursor_bg     = "#EA9A97",
    cursor_fg     = "#232136",
    cursor_border = "#EA9A97",

    -- Selection colors
    selection_bg  = "#44415A",
    selection_fg  = "#E0DEF4",

    -- Split separator color
    split         = "#56526E",

    -- Scrollbar thumb color
    scrollbar_thumb = "#56526E",

    -- Visual bell color
    visual_bell   = "#393552",

    -- Compose cursor (for IME)
    compose_cursor = "#EA9A97",

    -- Normal colors
    ansi = {
      "#393552",
      "#EB6F92",
      "#3E8FB0",
      "#F6C177",
      "#9CCFD8",
      "#C4A7E7",
      "#EA9A97",
      "#E0DEF4",
    },

    -- Bright colors
    brights = {
      "#6E6A86",
      "#EB6F92",
      "#3E8FB0",
      "#F6C177",
      "#9CCFD8",
      "#C4A7E7",
      "#EA9A97",
      "#E0DEF4",
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#EA9A97",
      [17] = "#F080A0",
    },

    -- Tab bar colors
    tab_bar = {
      background = "#2A273F",

      active_tab = {
        bg_color = "#393552",
        fg_color = "#EA9A97",
      },

      inactive_tab = {
        bg_color = "#232136",
        fg_color = "#A5A0BB",
      },

      inactive_tab_hover = {
        bg_color = "#2A273F",
        fg_color = "#E0DEF4",
      },

      new_tab = {
        bg_color = "#2A273F",
        fg_color = "#A5A0BB",
      },

      new_tab_hover = {
        bg_color = "#393552",
        fg_color = "#E0DEF4",
      },

      inactive_tab_edge = "#44415A",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#2A273F",
    active_titlebar_fg = "#E0DEF4",
    inactive_titlebar_bg = "#2A273F",
    inactive_titlebar_fg = "#A5A0BB",
    button_fg = "#E0DEF4",
    button_bg = "#232136",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#2A273F"
  config.command_palette_fg_color = "#E0DEF4"
end

return M
