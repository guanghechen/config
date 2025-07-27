#! /usr/bin/env bash

function _ghc_tmux_pane_status_toggle_ {
  local mode=$(tmux show -gqv @GHC_PSL_MODE)
  if [ -z "$mode" ]; then
    mode="01"
    tmux set -g @GHC_PSL_MODE "$mode"
  elif [ "$mode" == "00" ]; then
    mode="01"
    tmux set -g @GHC_PSL_MODE "$mode"
  elif [ "$mode" == "01" ]; then
    mode="00"
    tmux set -g @GHC_PSL_MODE "$mode"
  fi

  if [ "$mode" == "00" ]; then
    tmux set-option pane-border-status off
  elif [ "$mode" == "01" ]; then
    tmux set-option pane-border-status top
  fi

  tmux source-file "$HOME/.config/tmux/conf/variable.tmux.conf"
  tmux refresh-client -S
}

_ghc_tmux_pane_status_toggle_
