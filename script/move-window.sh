#! /usr/bin/env bash

function _ghc_tmux_move_window_ {
  local target_session_name=$1
  if [ -z "${target_session_name}" ]; then
    return 0
  fi

  local current_session_name
  local current_window_index
  local current_session_window_count
  local created_target=0
  local switched_client=0

  current_session_name=$(tmux display-message -p '#{session_name}')
  current_window_index=$(tmux display-message -p '#{window_index}')
  current_session_window_count=$(tmux list-windows -t "${current_session_name}" | wc -l)

  if [ "${current_session_name}" = "${target_session_name}" ]; then
    return 0
  fi

  if ! tmux has-session -t "${target_session_name}" 2>/dev/null; then
    tmux new-session -d -s "${target_session_name}"
    created_target=1
  fi

  if [ "${current_session_window_count}" -eq 1 ]; then
    tmux switch-client -t "${target_session_name}"
    switched_client=1
  fi

  if [ "${created_target}" -eq 1 ]; then
    local base_index
    base_index=$(tmux show-options -gv base-index 2>/dev/null || echo 0)
    tmux move-window -k -s "${current_session_name}:${current_window_index}" -t "${target_session_name}:${base_index}"
  else
    tmux move-window -s "${current_session_name}:${current_window_index}" -t "${target_session_name}:"
  fi

  if [ "${switched_client}" -eq 0 ]; then
    tmux switch-client -t "${target_session_name}"
  fi
}

_ghc_tmux_move_window_ "$1"
