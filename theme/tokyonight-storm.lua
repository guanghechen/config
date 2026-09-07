-- tokyonight-storm

---@class theme.tokyonight_storm
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#24283b",
    foreground    = "#c0caf5",

    cursor_bg     = "#bb9af7",
    cursor_fg     = "#24283b",
    cursor_border = "#bb9af7",

    selection_bg  = "#30374e",
    selection_fg  = "#c0caf5",
    split         = "#48536f",
    scrollbar_thumb = "#48536f",
    visual_bell   = "#292e42",
    compose_cursor = "#ff9e64",

    -- Official ANSI slots; bright accents use upstream HSLuv-generated values.
    ansi = {
      "#1d202f",
      "#f7768e",
      "#9ece6a",
      "#e0af68",
      "#7aa2f7",
      "#bb9af7",
      "#7dcfff",
      "#a9b1d6",
    },
    brights = {
      "#414868",
      "#ff899d",
      "#9fe044",
      "#faba4a",
      "#8db0ff",
      "#c7a9ff",
      "#a4daff",
      "#c0caf5",
    },
    indexed = {
      [16] = "#ff9e64",
      [17] = "#db4b4b",
    },

    tab_bar = {
      background = "#1b1e2d",
      active_tab = {
        bg_color = "#bb9af7",
        fg_color = "#24283b",
      },
      inactive_tab = {
        bg_color = "#1f2335",
        fg_color = "#a9b1d6",
      },
      inactive_tab_hover = {
        bg_color = "#292e42",
        fg_color = "#c0caf5",
      },
      new_tab = {
        bg_color = "#1f2335",
        fg_color = "#bb9af7",
      },
      new_tab_hover = {
        bg_color = "#30374e",
        fg_color = "#c0caf5",
      },
      inactive_tab_edge = "#292e42",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#1f2335",
    active_titlebar_fg = "#c0caf5",
    inactive_titlebar_bg = "#1f2335",
    inactive_titlebar_fg = "#a9b1d6",
    button_fg = "#c0caf5",
    button_bg = "#1f2335",
  }

  config.command_palette_bg_color = "#292e42"
  config.command_palette_fg_color = "#c0caf5"
end

return M
