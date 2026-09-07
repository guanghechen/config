-- kanagawa-dragon

---@class theme.kanagawa_dragon
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#181616",
    foreground    = "#C5C9C5",

    cursor_bg     = "#C4B28A",
    cursor_fg     = "#181616",
    cursor_border = "#C4B28A",

    selection_bg  = "#303632",
    selection_fg  = "#C5C9C5",
    split         = "#50534E",
    scrollbar_thumb = "#50534E",
    visual_bell   = "#282727",
    compose_cursor = "#BF9D85",

    -- Official Kanagawa ANSI colors, independent from readable app accents.
    ansi = {
      "#0D0C0C",
      "#C4746E",
      "#8A9A7B",
      "#C4B28A",
      "#8BA4B0",
      "#A292A3",
      "#8EA4A2",
      "#C8C093",
    },
    brights = {
      "#A6A69C",
      "#E46876",
      "#87A987",
      "#E6C384",
      "#7FB4CA",
      "#938AA9",
      "#7AA89F",
      "#C5C9C5",
    },
    indexed = {
      [16] = "#B6927B",
      [17] = "#B98D7B",
    },

    tab_bar = {
      background = "#12120F",
      active_tab = {
        bg_color = "#C4B28A",
        fg_color = "#181616",
      },
      inactive_tab = {
        bg_color = "#12120F",
        fg_color = "#A6A69C",
      },
      inactive_tab_hover = {
        bg_color = "#282727",
        fg_color = "#C5C9C5",
      },
      new_tab = {
        bg_color = "#12120F",
        fg_color = "#8BA4B0",
      },
      new_tab_hover = {
        bg_color = "#303632",
        fg_color = "#C5C9C5",
      },
      inactive_tab_edge = "#282727",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#12120F",
    active_titlebar_fg = "#C5C9C5",
    inactive_titlebar_bg = "#12120F",
    inactive_titlebar_fg = "#A6A69C",
    button_fg = "#C5C9C5",
    button_bg = "#12120F",
  }

  config.command_palette_bg_color = "#282727"
  config.command_palette_fg_color = "#C5C9C5"
end

return M
