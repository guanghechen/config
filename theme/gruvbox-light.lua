-- gruvbox-light

---@class theme.gruvbox_light
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#F2E5BC",
    foreground    = "#32302F",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#B16286",
    cursor_fg     = "#EBDBB2",
    cursor_border = "#B16286",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#A89984",
    selection_fg  = "#32302F",

    -- Split separator color
    split         = "#7C6F64",

    -- Scrollbar thumb color
    scrollbar_thumb = "#A89984",

    -- Visual bell color
    visual_bell   = "#D5C4A1",

    -- Compose cursor (for IME)
    compose_cursor = "#D65D0E",

    -- Normal colors
    ansi = {
      "#F2E5BC",  -- black (surface1 for dark themes, subtext1 for latte)
      "#CC241D",
      "#98971A",
      "#D79921",
      "#458588",
      "#B16286",
      "#689D6A",
      "#3C3836",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#928374",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#9D0006",
      "#79740E",
      "#B57614",
      "#076678",
      "#8F3F71",
      "#427B58",
      "#504945",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#D65D0E",
      [17] = "#B16286",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#EBDBB2",

      active_tab = {
        bg_color = "#B16286",
        fg_color = "#EBDBB2",
      },

      inactive_tab = {
        bg_color = "#EBDBB2",
        fg_color = "#32302F",
      },

      inactive_tab_hover = {
        bg_color = "#F2E5BC",
        fg_color = "#32302F",
      },

      new_tab = {
        bg_color = "#D5C4A1",
        fg_color = "#32302F",
      },

      new_tab_hover = {
        bg_color = "#BDAE93",
        fg_color = "#32302F",
      },

      inactive_tab_edge = "#D5C4A1",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#EBDBB2",
    active_titlebar_fg = "#32302F",
    inactive_titlebar_bg = "#EBDBB2",
    inactive_titlebar_fg = "#32302F",
    button_fg = "#32302F",
    button_bg = "#F2E5BC",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#EBDBB2"
  config.command_palette_fg_color = "#32302F"
end

return M
