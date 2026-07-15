#! /usr/bin/env bash

readonly GHC_MOVE_PANE_TARGET_OPTION='@GHC_MOVE_PANE_TARGET'

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
  local window_separator=$'\t'

  while IFS="${window_separator}" read -r window_index window_id window_name; do
    if [ "${window_index}" = "${target_window}" ]; then
      printf '%s' "${window_id}"
      return 0
    fi

    if [ "${window_name}" = "${target_window}" ]; then
      matched_window_id=${window_id}
      match_count=$((match_count + 1))
    fi
  done < <(tmux list-windows -t "${session_name}" -F "#{window_index}${window_separator}#{window_id}${window_separator}#{window_name}")

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
  local source_pane_id=$1
  if [ -z "${source_pane_id}" ]; then
    _ghc_tmux_notify_ "missing source pane"
    return 1
  fi

  local target_window
  if ! target_window=$(tmux show-options -pv -t "${source_pane_id}" "${GHC_MOVE_PANE_TARGET_OPTION}" 2>/dev/null); then
    _ghc_tmux_notify_ "move target unavailable for pane: ${source_pane_id}"
    return 1
  fi

  # Consume before moving so failures cannot leave stale input on the pane.
  if ! tmux set-option -pu -t "${source_pane_id}" "${GHC_MOVE_PANE_TARGET_OPTION}"; then
    _ghc_tmux_notify_ "failed to clear target for pane: ${source_pane_id}"
    return 1
  fi

  if [ -z "${target_window}" ]; then
    return 0
  fi

  local session_name
  local source_window_id
  local target_window_id
  local find_status

  session_name=$(tmux display-message -p -t "${source_pane_id}" '#{session_name}')
  source_window_id=$(tmux display-message -p -t "${source_pane_id}" '#{window_id}')

  target_window_id=$(_ghc_tmux_find_window_ "${session_name}" "${target_window}")
  find_status=$?

  if [ "${find_status}" -eq 2 ]; then
    _ghc_tmux_notify_ "ambiguous window name: ${target_window}"
    return 1
  fi

  if [ "${find_status}" -eq 0 ]; then
    if [ "${target_window_id}" = "${source_window_id}" ]; then
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

  if ! tmux rename-window -t "${source_pane_id}" "${target_window}"; then
    _ghc_tmux_notify_ "rename-window failed: ${target_window}"
    return 1
  fi
}

_ghc_tmux_move_pane_ "$1"
