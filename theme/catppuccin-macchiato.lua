-- catppuccin-macchiato

---@class theme.catppuccin_macchiato
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#24273A",
    foreground    = "#CAD3F5",

    cursor_bg     = "#C6A0F6",
    cursor_fg     = "#24273A",
    cursor_border = "#C6A0F6",

    selection_bg  = "#494D64",
    selection_fg  = "#CAD3F5",
    split         = "#5B6078",
    scrollbar_thumb = "#5B6078",
    visual_bell   = "#363A4F",
    compose_cursor = "#F5A97F",

    -- Official ANSI colors, including Latte's light-theme neutral slots.
    ansi = {
      "#494D64",
      "#ED8796",
      "#A6DA95",
      "#EED49F",
      "#8AADF4",
      "#F5BDE6",
      "#8BD5CA",
      "#A5ADCB",
    },
    brights = {
      "#5B6078",
      "#ED8796",
      "#A6DA95",
      "#EED49F",
      "#8AADF4",
      "#F5BDE6",
      "#8BD5CA",
      "#B8C0E0",
    },
    indexed = {
      [16] = "#F5A97F",
      [17] = "#F4DBD6",
    },

    tab_bar = {
      background = "#181926",
      active_tab = {
        bg_color = "#C6A0F6",
        fg_color = "#24273A",
      },
      inactive_tab = {
        bg_color = "#1E2030",
        fg_color = "#B8C0E0",
      },
      inactive_tab_hover = {
        bg_color = "#363A4F",
        fg_color = "#CAD3F5",
      },
      new_tab = {
        bg_color = "#1E2030",
        fg_color = "#C6A0F6",
      },
      new_tab_hover = {
        bg_color = "#494D64",
        fg_color = "#CAD3F5",
      },
      inactive_tab_edge = "#363A4F",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#1E2030",
    active_titlebar_fg = "#CAD3F5",
    inactive_titlebar_bg = "#1E2030",
    inactive_titlebar_fg = "#B8C0E0",
    button_fg = "#CAD3F5",
    button_bg = "#1E2030",
  }

  config.command_palette_bg_color = "#363A4F"
  config.command_palette_fg_color = "#CAD3F5"
end

return M
