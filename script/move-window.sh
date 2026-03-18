#! /usr/bin/env bash

function _ghc_tmux_move_window_ {
  local target_session_name=$1
  if [ -z "${target_session_name}" ]; then
    return 0
  fi

  local current_session_name
  local current_window_index
  local source_window
  local target_window
  local created_target=0

  current_session_name=$(tmux display-message -p '#{session_name}')
  current_window_index=$(tmux display-message -p '#{window_index}')
  source_window="${current_session_name}:${current_window_index}"

  if [ "${current_session_name}" = "${target_session_name}" ]; then
    return 0
  fi

  if ! tmux has-session -t "${target_session_name}" 2>/dev/null; then
    tmux new-session -d -s "${target_session_name}"
    created_target=1
  fi

  if [ "${created_target}" -eq 1 ]; then
    local base_index
    base_index=$(tmux display-message -p -t "${target_session_name}" '#{base-index}')
    target_window="${target_session_name}:${base_index}"
    tmux link-window -k -s "${source_window}" -t "${target_window}"
  else
    target_window="${target_session_name}:"
    tmux link-window -s "${source_window}" -t "${target_window}"
  fi

  tmux switch-client -t "${target_session_name}"
  tmux unlink-window -t "${source_window}"
}

_ghc_tmux_move_window_ "$1"
