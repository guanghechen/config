#! /usr/bin/env bash

function _ghc_tmux_toggle_theme_ {
  local current_theme=$(tmux show-environment -g @GHC_TMUX_THEME 2>/dev/null | cut -d '=' -f 2)
  local current_mode=$(echo $current_theme | rg -o '_([a-zA-Z0-9]+)$' -r '$1')

  local next_theme=$current_theme
  if [ "$current_mode" == "light" ]; then
    next_theme=$(echo $current_theme | rg '_light$' -r '_dark')
  elif [ "$current_mode" == "dark" ]; then
    next_theme=$(echo $current_theme | rg '_dark$' -r '_light')
  fi

  node $HOME/.config/guanghechen/config/theme/apply_theme.mjs "$next_theme"
}

_ghc_tmux_toggle_theme_
