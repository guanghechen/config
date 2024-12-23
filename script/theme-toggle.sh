#! /usr/bin/env bash

function _ghc_tmux_theme_toggle_ {
  local theme=$(tmux show -gqv @GHC_TMUX_THEME)
  if [ -z "$theme" ]; then
    theme="gruvbox_light"
    tmux set -g @GHC_TMUX_THEME "$theme"
  fi
  node $HOME/.config/guanghechen/config/theme/toggle_theme.mjs "$theme"
}

_ghc_tmux_theme_toggle_
