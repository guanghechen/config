-- catppuccin-latte

---@class theme.catppuccin_latte
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#EFF1F5",
    foreground    = "#303446",

    cursor_bg     = "#722FBC",
    cursor_fg     = "#EFF1F5",
    cursor_border = "#722FBC",

    selection_bg  = "#CCD0DA",
    selection_fg  = "#303446",
    split         = "#BCC0CC",
    scrollbar_thumb = "#ACB0BE",
    visual_bell   = "#DCE0E8",
    compose_cursor = "#973C0F",

    -- Official ANSI colors, including Latte's light-theme neutral slots.
    ansi = {
      "#5C5F77",
      "#D20F39",
      "#40A02B",
      "#DF8E1D",
      "#1E66F5",
      "#EA76CB",
      "#179299",
      "#ACB0BE",
    },
    brights = {
      "#6C6F85",
      "#D20F39",
      "#40A02B",
      "#DF8E1D",
      "#1E66F5",
      "#EA76CB",
      "#179299",
      "#BCC0CC",
    },
    indexed = {
      [16] = "#FE640B",
      [17] = "#DC8A78",
    },

    tab_bar = {
      background = "#DCE0E8",
      active_tab = {
        bg_color = "#722FBC",
        fg_color = "#EFF1F5",
      },
      inactive_tab = {
        bg_color = "#E6E9EF",
        fg_color = "#4C4F69",
      },
      inactive_tab_hover = {
        bg_color = "#DCE0E8",
        fg_color = "#303446",
      },
      new_tab = {
        bg_color = "#E6E9EF",
        fg_color = "#722FBC",
      },
      new_tab_hover = {
        bg_color = "#CCD0DA",
        fg_color = "#303446",
      },
      inactive_tab_edge = "#DCE0E8",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#E6E9EF",
    active_titlebar_fg = "#303446",
    inactive_titlebar_bg = "#E6E9EF",
    inactive_titlebar_fg = "#4C4F69",
    button_fg = "#303446",
    button_bg = "#E6E9EF",
  }

  config.command_palette_bg_color = "#DCE0E8"
  config.command_palette_fg_color = "#303446"
end

return M
