-- vsc-light-modern

---@class theme.vsc_light_modern
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    -- Primary colors
    background    = "#FFFFFF",
    foreground    = "#000000",

    -- Cursor colors (following official catppuccin theme)
    cursor_bg     = "#E75480",
    cursor_fg     = "#F2F2F2",
    cursor_border = "#E75480",

    -- Selection colors (following official catppuccin theme)
    selection_bg  = "#CCCCCC",
    selection_fg  = "#000000",

    -- Split separator color
    split         = "#8B949E",

    -- Scrollbar thumb color
    scrollbar_thumb = "#CCCCCC",

    -- Visual bell color
    visual_bell   = "#E8E8E8",

    -- Compose cursor (for IME)
    compose_cursor = "#C72E0F",

    -- Normal colors
    ansi = {
      "#FFFFFF",  -- black (surface1 for dark themes, subtext1 for latte)
      "#F85149",
      "#2EA043",
      "#795E26",
      "#005FB8",
      "#AF00DB",
      "#267F99",
      "#3B3B3B",  -- white (subtext1 for dark themes, surface2 for latte)
    },

    -- Bright colors
    brights = {
      "#939393",  -- bright black (surface2 for dark themes, subtext0 for latte)
      "#F85149",
      "#098658",
      "#795E26",
      "#001080",
      "#AF00DB",
      "#0070C1",
      "#616161",  -- bright white (subtext0 for dark themes, surface1 for latte)
    },

    -- Indexed colors (extended palette)
    indexed = {
      [16] = "#C72E0F",
      [17] = "#E75480",
    },

    -- Tab bar colors (following official catppuccin theme)
    tab_bar = {
      background = "#F2F2F2",

      active_tab = {
        bg_color = "#AF00DB",
        fg_color = "#F2F2F2",
      },

      inactive_tab = {
        bg_color = "#F2F2F2",
        fg_color = "#000000",
      },

      inactive_tab_hover = {
        bg_color = "#FFFFFF",
        fg_color = "#000000",
      },

      new_tab = {
        bg_color = "#E8E8E8",
        fg_color = "#000000",
      },

      new_tab_hover = {
        bg_color = "#D3D3D3",
        fg_color = "#000000",
      },

      inactive_tab_edge = "#E8E8E8",
    },
  }

  -- Window frame colors
  config.window_frame = {
    active_titlebar_bg = "#F2F2F2",
    active_titlebar_fg = "#000000",
    inactive_titlebar_bg = "#F2F2F2",
    inactive_titlebar_fg = "#000000",
    button_fg = "#000000",
    button_bg = "#FFFFFF",
  }

  -- Command palette colors
  config.command_palette_bg_color = "#F2F2F2"
  config.command_palette_fg_color = "#000000"
end

return M
