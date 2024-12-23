#! /usr/bin/env bash

function _ghc_tmux_status_toggle_ {
  local status_mode=$(tmux show -gqv @GHC_SL_MODE)

  if [ -z "$status_mode" ]; then
    tmux set -g @GHC_SL_MODE "02"
  elif [ "$status_mode" == "00" ]; then
    tmux set -g @GHC_SL_MODE "01"
  elif [ "$status_mode" == "01" ]; then
    tmux set -g @GHC_SL_MODE "02"
  elif [ "$status_mode" == "02" ]; then
    tmux set -g @GHC_SL_MODE "00"
  fi

  tmux source-file "$HOME/.config/tmux/conf/variable.tmux.conf"
  tmux refresh-client -S
}

_ghc_tmux_status_toggle_
