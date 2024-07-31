#! /usr/bin/env bash

function _ghc_tmux_move_window_ {
  if [ "$(tmux list-sessions | wc -l)" -eq 1 ]; then
    return 0
  fi

  local target_session_name=$1

  if [ "$(tmux list-windows | wc -l)" -eq 1 ]; then
    tmux move-window -t "${target_session_name}"
    tmux detach-client 2>/dev/null
    tmux attach -t "${target_session_name}"
  else
    tmux move-window -t "${target_session_name}"
    tmux switch-client -t "${target_session_name}"
  fi
}

_ghc_tmux_move_window_ "$1"
