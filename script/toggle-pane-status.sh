#! /usr/bin/env bash

function _ghc_tmux_toggle_pane_status_ {
  local direction="${1:-forward}"
  local mode
  mode=$(tmux show -gqv @GHC_PSL_MODE)

  if [ -z "$mode" ]; then
    tmux set -g @GHC_PSL_MODE "01"
  elif [ "$direction" == "forward" ]; then
    case "$mode" in
      "01") tmux set -g @GHC_PSL_MODE "02" ;;
      "02") tmux set -g @GHC_PSL_MODE "11" ;;
      "11") tmux set -g @GHC_PSL_MODE "12" ;;
      "12") tmux set -g @GHC_PSL_MODE "01" ;;
      *) tmux set -g @GHC_PSL_MODE "01" ;;
    esac
  elif [ "$direction" == "backward" ]; then
    case "$mode" in
      "01") tmux set -g @GHC_PSL_MODE "12" ;;
      "02") tmux set -g @GHC_PSL_MODE "01" ;;
      "11") tmux set -g @GHC_PSL_MODE "02" ;;
      "12") tmux set -g @GHC_PSL_MODE "11" ;;
      *) tmux set -g @GHC_PSL_MODE "01" ;;
    esac
  fi

  bash "$HOME/.config/tmux/script/load-theme.sh"
}

_ghc_tmux_toggle_pane_status_ "$@"
