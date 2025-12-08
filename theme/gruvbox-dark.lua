-- gruvbox-dark

---@class theme.gruvbox_dark
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background = "#32302F",
    foreground = "#F2E5BC",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg = "#D3869B",
    cursor_fg = "#3C3836",
    cursor_border = "#D3869B",

    -- Selection colors (following official catppuccin theme)
    selection_bg = "#7C6F64",
    selection_fg = "#F2E5BC",

    -- Split separator color
    split = "#A89984",

    -- Scrollbar thumb color
    scrollbar_thumb = "#7C6F64",

    -- Visual bell color
    visual_bell = "#504945",

    -- Compose cursor (for IME)
    compose_cursor = "#D65D0E",

    -- Normal colors
    ansi = {
      "#32302F", -- black (surface1 for dark themes, subtext1 for latte)
      "#CC241D",
      "#98971A",
      "#D79921",
      "#458588",
      "#B16286",
      "#689D6A",
      "#EBDBB2", -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#928374", -- bright black (surface2 for dark themes, subtext0 for latte)
      "#FB4934",
      "#B8BB26",
      "#FABD2F",
      "#83A598",
      "#D3869B",
      "#8EC07C",
      "#D5C4A1", -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#D65D0E",
      [17] = "#D3869B",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#3C3836",

      active_tab = {
        bg_color = "#B16286",
        fg_color = "#3C3836",
      },

      inactive_tab = {
        bg_color = "#3C3836",
        fg_color = "#F2E5BC",
      },

      inactive_tab_hover = {
        bg_color = "#32302F",
        fg_color = "#F2E5BC",
      },

      new_tab = {
        bg_color = "#504945",
        fg_color = "#F2E5BC",
      },

      new_tab_hover = {
        bg_color = "#665C54",
        fg_color = "#F2E5BC",
      },

      inactive_tab_edge = "#504945",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#3C3836",
    active_titlebar_fg = "#F2E5BC",
    inactive_titlebar_bg = "#3C3836",
    inactive_titlebar_fg = "#F2E5BC",
    button_fg = "#F2E5BC",
    button_bg = "#32302F",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#3C3836"
  config.command_palette_fg_color = "#F2E5BC"
end

return M
