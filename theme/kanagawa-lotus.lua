-- kanagawa-lotus

---@class theme.kanagawa_lotus
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#F2ECBC",
    foreground    = "#38384D",

    cursor_bg     = "#655A35",
    cursor_fg     = "#F2ECBC",
    cursor_border = "#655A35",

    selection_bg  = "#D5D6CE",
    selection_fg  = "#38384D",
    split         = "#ACA99A",
    scrollbar_thumb = "#ACA99A",
    visual_bell   = "#DCD5AC",
    compose_cursor = "#914600",

    -- Official Kanagawa ANSI colors, independent from readable app accents.
    ansi = {
      "#1F1F28",
      "#C84053",
      "#6F894E",
      "#77713F",
      "#4D699B",
      "#B35B79",
      "#597B75",
      "#545464",
    },
    brights = {
      "#8A8980",
      "#D7474B",
      "#6E915F",
      "#836F4A",
      "#6693BF",
      "#624C83",
      "#5E857A",
      "#43436C",
    },
    indexed = {
      [16] = "#E98A00",
      [17] = "#E82424",
    },

    tab_bar = {
      background = "#E5DDB0",
      active_tab = {
        bg_color = "#655A35",
        fg_color = "#F2ECBC",
      },
      inactive_tab = {
        bg_color = "#E5DDB0",
        fg_color = "#545464",
      },
      inactive_tab_hover = {
        bg_color = "#DCD5AC",
        fg_color = "#38384D",
      },
      new_tab = {
        bg_color = "#E5DDB0",
        fg_color = "#3E5A87",
      },
      new_tab_hover = {
        bg_color = "#D5D6CE",
        fg_color = "#38384D",
      },
      inactive_tab_edge = "#DCD5AC",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#E5DDB0",
    active_titlebar_fg = "#38384D",
    inactive_titlebar_bg = "#E5DDB0",
    inactive_titlebar_fg = "#545464",
    button_fg = "#38384D",
    button_bg = "#E5DDB0",
  }

  config.command_palette_bg_color = "#DCD5AC"
  config.command_palette_fg_color = "#38384D"
end

return M
