local env = require("env")

local config = {
  -- Key bindings
  disable_default_key_bindings = true,

  -- Tab bar
  enable_tab_bar = true,
  hide_tab_bar_if_only_one_tab = true,
  show_new_tab_button_in_tab_bar = false,
  show_tab_index_in_tab_bar = false,
  tab_bar_at_bottom = false,
  tab_max_width = 32,
  use_fancy_tab_bar = false,

  -- Window
  initial_cols = 120,
  initial_rows = 40,
  native_macos_fullscreen_mode = true,
  window_decorations = "RESIZE",
  window_padding = {
    bottom = 0,
    left = 0,
    right = 0,
    top = 0,
  },

  -- macOS specific
  send_composed_key_when_left_alt_is_pressed = false,
  send_composed_key_when_right_alt_is_pressed = true,
}

local ok, theme = pcall(require, "local.theme")
if not ok then
  theme = require("theme.vsc-dark-modern")
end

theme.setup(config)
require("conf.tabline").setup(config)

if env.IS_MAC then
  require("conf.mac").setup(config)
elseif env.IS_NIX then
  require("conf.nix").setup(config)
elseif env.IS_WSL then
  require("conf.wsl").setup(config)
elseif env.IS_WIN then
  require("conf.win").setup(config)
end

return config
