-- tokyonight-day

---@class theme.tokyonight_day
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#e1e2e7",
    foreground    = "#293552",

    cursor_bg     = "#663999",
    cursor_fg     = "#e1e2e7",
    cursor_border = "#663999",

    selection_bg  = "#ccd1df",
    selection_fg  = "#293552",
    split         = "#9ca6be",
    scrollbar_thumb = "#9ca6be",
    visual_bell   = "#d5d9e4",
    compose_cursor = "#7d4005",

    -- Official ANSI slots; bright accents use upstream HSLuv-generated values.
    ansi = {
      "#b4b5b9",
      "#f52a65",
      "#587539",
      "#8c6c3e",
      "#2e7de9",
      "#9854f1",
      "#007197",
      "#6172b0",
    },
    brights = {
      "#a1a6c5",
      "#ff4774",
      "#5c8524",
      "#a27629",
      "#358aff",
      "#a463ff",
      "#007ea8",
      "#3760bf",
    },
    indexed = {
      [16] = "#b15c00",
      [17] = "#c64343",
    },

    tab_bar = {
      background = "#c1c9df",
      active_tab = {
        bg_color = "#663999",
        fg_color = "#e1e2e7",
      },
      inactive_tab = {
        bg_color = "#d0d5e3",
        fg_color = "#445270",
      },
      inactive_tab_hover = {
        bg_color = "#d5d9e4",
        fg_color = "#293552",
      },
      new_tab = {
        bg_color = "#d0d5e3",
        fg_color = "#663999",
      },
      new_tab_hover = {
        bg_color = "#ccd1df",
        fg_color = "#293552",
      },
      inactive_tab_edge = "#d5d9e4",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#d0d5e3",
    active_titlebar_fg = "#293552",
    inactive_titlebar_bg = "#d0d5e3",
    inactive_titlebar_fg = "#445270",
    button_fg = "#293552",
    button_bg = "#d0d5e3",
  }

  config.command_palette_bg_color = "#d5d9e4"
  config.command_palette_fg_color = "#293552"
end

return M
