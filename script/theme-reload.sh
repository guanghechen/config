#! /usr/bin/env bash

function _ghc_tmux_theme_reload_ {
  bash "$HOME/.config/tmux/script/status-load.sh"
  if [ -f "$HOME/.config/tmux/local/theme.tmux.conf" ]; then
    tmux source "$HOME/.config/tmux/local/theme.tmux.conf"
  fi
  tmux refresh-client -S
}

_ghc_tmux_theme_reload_
