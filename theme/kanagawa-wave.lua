-- kanagawa-wave

---@class theme.kanagawa_wave
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#1F1F28",
    foreground    = "#DCD7BA",

    cursor_bg     = "#E6C384",
    cursor_fg     = "#1F1F28",
    cursor_border = "#E6C384",

    selection_bg  = "#223249",
    selection_fg  = "#DCD7BA",
    split         = "#54546D",
    scrollbar_thumb = "#54546D",
    visual_bell   = "#2A2A37",
    compose_cursor = "#FFA066",

    -- Official Kanagawa ANSI colors, independent from readable app accents.
    ansi = {
      "#16161D",
      "#C34043",
      "#76946A",
      "#C0A36E",
      "#7E9CD8",
      "#957FB8",
      "#6A9589",
      "#C8C093",
    },
    brights = {
      "#727169",
      "#E82424",
      "#98BB6C",
      "#E6C384",
      "#7FB4CA",
      "#938AA9",
      "#7AA89F",
      "#DCD7BA",
    },
    indexed = {
      [16] = "#FFA066",
      [17] = "#FF5D62",
    },

    tab_bar = {
      background = "#16161D",
      active_tab = {
        bg_color = "#E6C384",
        fg_color = "#1F1F28",
      },
      inactive_tab = {
        bg_color = "#16161D",
        fg_color = "#C8C093",
      },
      inactive_tab_hover = {
        bg_color = "#2A2A37",
        fg_color = "#DCD7BA",
      },
      new_tab = {
        bg_color = "#16161D",
        fg_color = "#7E9CD8",
      },
      new_tab_hover = {
        bg_color = "#223249",
        fg_color = "#DCD7BA",
      },
      inactive_tab_edge = "#2A2A37",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#16161D",
    active_titlebar_fg = "#DCD7BA",
    inactive_titlebar_bg = "#16161D",
    inactive_titlebar_fg = "#C8C093",
    button_fg = "#DCD7BA",
    button_bg = "#16161D",
  }

  config.command_palette_bg_color = "#2A2A37"
  config.command_palette_fg_color = "#DCD7BA"
end

return M
