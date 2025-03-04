#! /usr/bin/env bash

function _ghc_tmux_theme_load_ {
  if [ -f "$HOME/.config/tmux/local/theme.tmux.conf" ]; then
    tmux source-file "$HOME/.config/tmux/local/theme.tmux.conf"
  else
    local theme=$(tmux show -gqv @GHC_TMUX_THEME)
    if [ -z "$theme" ]; then
      theme="catppuccin-mocha"
      tmux set -g @GHC_TMUX_THEME "$theme"
    fi
    tmux source-file "$HOME/.config/tmux/theme/${theme}.tmux.conf"
  fi
}

_ghc_tmux_theme_load_
