#! /usr/bin/env bash

function _ghc_tmux_toggle_status_ {
  local direction="${1:-forward}"
  local mode=$(tmux show -gqv @GHC_SL_MODE)

  if [ -z "$mode" ]; then
    tmux set -g @GHC_SL_MODE "01"
  elif [ "$direction" == "forward" ]; then
    case "$mode" in
      "00") tmux set -g @GHC_SL_MODE "01" ;;
      "01") tmux set -g @GHC_SL_MODE "02" ;;
      "02") tmux set -g @GHC_SL_MODE "03" ;;
      "03") tmux set -g @GHC_SL_MODE "10" ;;
      "10") tmux set -g @GHC_SL_MODE "11" ;;
      "11") tmux set -g @GHC_SL_MODE "12" ;;
      "12") tmux set -g @GHC_SL_MODE "13" ;;
      "13") tmux set -g @GHC_SL_MODE "00" ;;
    esac
  elif [ "$direction" == "backward" ]; then
    case "$mode" in
      "00") tmux set -g @GHC_SL_MODE "13" ;;
      "01") tmux set -g @GHC_SL_MODE "00" ;;
      "02") tmux set -g @GHC_SL_MODE "01" ;;
      "03") tmux set -g @GHC_SL_MODE "02" ;;
      "10") tmux set -g @GHC_SL_MODE "03" ;;
      "11") tmux set -g @GHC_SL_MODE "10" ;;
      "12") tmux set -g @GHC_SL_MODE "11" ;;
      "13") tmux set -g @GHC_SL_MODE "12" ;;
    esac
  fi

  bash "$HOME/.config/tmux/script/load-theme.sh"
}

_ghc_tmux_toggle_status_ "$@"
