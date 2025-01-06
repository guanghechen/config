#! /usr/bin/env bash

function _ghc_tmux_status_load_ {
  local status_mode=$(tmux show -gqv @GHC_SL_MODE)

  if [ -z "$status_mode" ]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      status_mode="02"
    else
      status_mode="01"
    fi
    tmux set -g @GHC_SL_MODE "$status_mode"
  fi

  if [ "$status_mode" == "00" ]; then
    tmux set-option status off
  elif [ "$status_mode" == "01" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme01.tmux.conf"
    tmux set-option status on
  elif [ "$status_mode" == "02" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme02.tmux.conf"
    tmux set-option status on
  fi
}

_ghc_tmux_status_load_
