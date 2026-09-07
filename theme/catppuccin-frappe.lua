-- catppuccin-frappe

---@class theme.catppuccin_frappe
local M = {}

---@param config table
function M.setup(config)
  config.colors = {
    background    = "#303446",
    foreground    = "#C6D0F5",

    cursor_bg     = "#CA9EE6",
    cursor_fg     = "#303446",
    cursor_border = "#CA9EE6",

    selection_bg  = "#51576D",
    selection_fg  = "#C6D0F5",
    split         = "#626880",
    scrollbar_thumb = "#626880",
    visual_bell   = "#414559",
    compose_cursor = "#EF9F76",

    -- Official ANSI colors, including Latte's light-theme neutral slots.
    ansi = {
      "#51576D",
      "#E78284",
      "#A6D189",
      "#E5C890",
      "#8CAAEE",
      "#F4B8E4",
      "#81C8BE",
      "#A5ADCE",
    },
    brights = {
      "#626880",
      "#E78284",
      "#A6D189",
      "#E5C890",
      "#8CAAEE",
      "#F4B8E4",
      "#81C8BE",
      "#B5BFE2",
    },
    indexed = {
      [16] = "#EF9F76",
      [17] = "#F2D5CF",
    },

    tab_bar = {
      background = "#232634",
      active_tab = {
        bg_color = "#CA9EE6",
        fg_color = "#303446",
      },
      inactive_tab = {
        bg_color = "#292C3C",
        fg_color = "#B5BFE2",
      },
      inactive_tab_hover = {
        bg_color = "#414559",
        fg_color = "#C6D0F5",
      },
      new_tab = {
        bg_color = "#292C3C",
        fg_color = "#CA9EE6",
      },
      new_tab_hover = {
        bg_color = "#51576D",
        fg_color = "#C6D0F5",
      },
      inactive_tab_edge = "#414559",
    },
  }

  config.window_frame = {
    active_titlebar_bg = "#292C3C",
    active_titlebar_fg = "#C6D0F5",
    inactive_titlebar_bg = "#292C3C",
    inactive_titlebar_fg = "#B5BFE2",
    button_fg = "#C6D0F5",
    button_bg = "#292C3C",
  }

  config.command_palette_bg_color = "#414559"
  config.command_palette_fg_color = "#C6D0F5"
end

return M
