-- catppuccin-mocha

---@class theme.catppuccin_mocha
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#1E1E2E",
    foreground    = "#CDD6F4",

    cursor_bg     = "#CBA6F7",
    cursor_fg     = "#1E1E2E",
    cursor_border = "#CBA6F7",

    selection_bg  = "#45475A",
    selection_fg  = "#CDD6F4",
    split         = "#585B70",
    scrollbar_thumb = "#585B70",
    visual_bell   = "#313244",
    compose_cursor = "#FAB387",

    -- Official ANSI colors, including Latte's light-theme neutral slots.
    ansi = {
      "#45475A",
      "#F38BA8",
      "#A6E3A1",
      "#F9E2AF",
      "#89B4FA",
      "#F5C2E7",
      "#94E2D5",
      "#A6ADC8",
    },
    brights = {
      "#585B70",
      "#F38BA8",
      "#A6E3A1",
      "#F9E2AF",
      "#89B4FA",
      "#F5C2E7",
      "#94E2D5",
      "#BAC2DE",
    },
    indexed = {
      [16] = "#FAB387",
      [17] = "#F5E0DC",
    },

    tab_bar = {
      background = "#11111B",
      active_tab = {
        bg_color = "#CBA6F7",
        fg_color = "#1E1E2E",
      },
      inactive_tab = {
        bg_color = "#181825",
        fg_color = "#BAC2DE",
      },
      inactive_tab_hover = {
        bg_color = "#313244",
        fg_color = "#CDD6F4",
      },
      new_tab = {
        bg_color = "#181825",
        fg_color = "#CBA6F7",
      },
      new_tab_hover = {
        bg_color = "#45475A",
        fg_color = "#CDD6F4",
      },
      inactive_tab_edge = "#313244",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#181825",
    active_titlebar_fg = "#CDD6F4",
    inactive_titlebar_bg = "#181825",
    inactive_titlebar_fg = "#BAC2DE",
    button_fg = "#CDD6F4",
    button_bg = "#181825",
  }

  config.command_palette_bg_color = "#313244"
  config.command_palette_fg_color = "#CDD6F4"
end

return M
