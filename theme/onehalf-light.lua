-- onehalf-light

---@class theme.onehalf_light
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#FAFAFA",
    foreground    = "#767A83",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#F07178",
    cursor_fg     = "#F0F0F0",
    cursor_border = "#F07178",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#D3D3D3",
    selection_fg  = "#767A83",

    -- Split separator color
    split         = "#383A42",

    -- Scrollbar thumb color
    scrollbar_thumb = "#D3D3D3",

    -- Visual bell color
    visual_bell   = "#EAEAEA",

    -- Compose cursor (for IME)
    compose_cursor = "#FF6A00",

    -- Normal colors
    ansi = {
      "#FAFAFA",  -- black (surface1 for dark themes, subtext1 for latte)
      "#E45649",
      "#50A14F",
      "#DEA95F",
      "#4078F2",
      "#A28DCD",
      "#0B8EC6",
      "#696D75",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#B7B7B7",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#D84A3D",
      "#7ECA9C",
      "#C18401",
      "#4078F2",
      "#B294BB",
      "#4EC9B0",
      "#5C5F66",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#FF6A00",
      [17] = "#F07178",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#F0F0F0",

      active_tab = {
        bg_color = "#A28DCD",
        fg_color = "#F0F0F0",
      },

      inactive_tab = {
        bg_color = "#F0F0F0",
        fg_color = "#767A83",
      },

      inactive_tab_hover = {
        bg_color = "#FAFAFA",
        fg_color = "#767A83",
      },

      new_tab = {
        bg_color = "#EAEAEA",
        fg_color = "#767A83",
      },

      new_tab_hover = {
        bg_color = "#DCDCDC",
        fg_color = "#767A83",
      },

      inactive_tab_edge = "#EAEAEA",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#F0F0F0",
    active_titlebar_fg = "#767A83",
    inactive_titlebar_bg = "#F0F0F0",
    inactive_titlebar_fg = "#767A83",
    button_fg = "#767A83",
    button_bg = "#FAFAFA",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#F0F0F0"
  config.command_palette_fg_color = "#767A83"
end

return M
