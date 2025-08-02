#! /usr/bin/env bash

function _ghc_tmux_toggle_status_ {
  local mode=$(tmux show -gqv @GHC_SL_MODE)

  if [ -z "$mode" ]; then
    tmux set -g @GHC_SL_MODE "01"
  elif [ "$mode" == "00" ]; then
    tmux set -g @GHC_SL_MODE "01"
  elif [ "$mode" == "01" ]; then
    tmux set -g @GHC_SL_MODE "02"
  elif [ "$mode" == "02" ]; then
    tmux set -g @GHC_SL_MODE "03"
  elif [ "$mode" == "03" ]; then
    tmux set -g @GHC_SL_MODE "10"
  elif [ "$mode" == "10" ]; then
    tmux set -g @GHC_SL_MODE "11"
  elif [ "$mode" == "11" ]; then
    tmux set -g @GHC_SL_MODE "12"
  elif [ "$mode" == "12" ]; then
    tmux set -g @GHC_SL_MODE "13"
  elif [ "$mode" == "13" ]; then
    tmux set -g @GHC_SL_MODE "00"
  fi

  bash "$HOME/.config/tmux/script/load-theme.sh"
}

_ghc_tmux_toggle_status_
