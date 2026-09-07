-- tokyonight-moon

---@class theme.tokyonight_moon
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#222436",
    foreground    = "#c8d3f5",

    cursor_bg     = "#c099ff",
    cursor_fg     = "#222436",
    cursor_border = "#c099ff",

    selection_bg  = "#343b54",
    selection_fg  = "#c8d3f5",
    split         = "#4c5878",
    scrollbar_thumb = "#4c5878",
    visual_bell   = "#2f334d",
    compose_cursor = "#ff966c",

    -- Official ANSI slots; bright accents use upstream HSLuv-generated values.
    ansi = {
      "#1b1d2b",
      "#ff757f",
      "#c3e88d",
      "#ffc777",
      "#82aaff",
      "#c099ff",
      "#86e1fc",
      "#828bb8",
    },
    brights = {
      "#444a73",
      "#ff8d94",
      "#c7fb6d",
      "#ffd8ab",
      "#9ab8ff",
      "#caabff",
      "#b2ebff",
      "#c8d3f5",
    },
    indexed = {
      [16] = "#ff966c",
      [17] = "#c53b53",
    },

    tab_bar = {
      background = "#191B29",
      active_tab = {
        bg_color = "#c099ff",
        fg_color = "#222436",
      },
      inactive_tab = {
        bg_color = "#1e2030",
        fg_color = "#aab6df",
      },
      inactive_tab_hover = {
        bg_color = "#2f334d",
        fg_color = "#c8d3f5",
      },
      new_tab = {
        bg_color = "#1e2030",
        fg_color = "#c099ff",
      },
      new_tab_hover = {
        bg_color = "#343b54",
        fg_color = "#c8d3f5",
      },
      inactive_tab_edge = "#2f334d",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#1e2030",
    active_titlebar_fg = "#c8d3f5",
    inactive_titlebar_bg = "#1e2030",
    inactive_titlebar_fg = "#aab6df",
    button_fg = "#c8d3f5",
    button_bg = "#1e2030",
  }

  config.command_palette_bg_color = "#2f334d"
  config.command_palette_fg_color = "#c8d3f5"
end

return M
