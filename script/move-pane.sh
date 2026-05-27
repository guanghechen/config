#! /usr/bin/env bash

function _ghc_tmux_notify_ {
  tmux display-message "[move-pane] $1"
}

function _ghc_tmux_find_window_ {
  local session_name=$1
  local target_window=$2
  local match_count=0
  local matched_window_id=""
  local window_index
  local window_id
  local window_name

  while read -r window_index window_id window_name; do
    if [ "${window_index}" = "${target_window}" ]; then
      printf '%s' "${window_id}"
      return 0
    fi

    if [ "${window_name}" = "${target_window}" ]; then
      matched_window_id=${window_id}
      match_count=$((match_count + 1))
    fi
  done < <(tmux list-windows -t "${session_name}" -F '#{window_index} #{window_id} #{window_name}')

  if [ "${match_count}" -eq 1 ]; then
    printf '%s' "${matched_window_id}"
    return 0
  fi

  if [ "${match_count}" -gt 1 ]; then
    return 2
  fi

  return 1
}

function _ghc_tmux_move_pane_ {
  local target_window=$1
  if [ -z "${target_window}" ]; then
    return 0
  fi

  local current_session_name
  local current_window_id
  local source_pane_id
  local target_window_id
  local find_status

  current_session_name=$(tmux display-message -p '#{session_name}')
  current_window_id=$(tmux display-message -p '#{window_id}')
  source_pane_id=$(tmux display-message -p '#{pane_id}')

  target_window_id=$(_ghc_tmux_find_window_ "${current_session_name}" "${target_window}")
  find_status=$?

  if [ "${find_status}" -eq 2 ]; then
    _ghc_tmux_notify_ "ambiguous window name: ${target_window}"
    return 1
  fi

  if [ "${find_status}" -eq 0 ]; then
    if [ "${target_window_id}" = "${current_window_id}" ]; then
      return 0
    fi

    if ! tmux join-pane -s "${source_pane_id}" -t "${target_window_id}"; then
      _ghc_tmux_notify_ "join-pane failed: ${target_window}"
      return 1
    fi

    tmux select-window -t "${target_window_id}" 2>/dev/null || true
    tmux select-pane -t "${source_pane_id}" 2>/dev/null || true
    return 0
  fi

  if ! tmux break-pane -s "${source_pane_id}" -n "${target_window}"; then
    _ghc_tmux_notify_ "break-pane failed: ${target_window}"
    return 1
  fi
}

_ghc_tmux_move_pane_ "$1"
