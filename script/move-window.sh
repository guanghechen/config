#! /usr/bin/env bash

function _ghc_tmux_notify_ {
  tmux display-message "[move-window] $1"
}

function _ghc_tmux_renumber_session_ {
  local session_name=$1

  if ! tmux has-session -t "${session_name}" 2>/dev/null; then
    return 0
  fi

  if ! tmux move-window -r -t "${session_name}:" 2>/dev/null; then
    _ghc_tmux_notify_ "renumber-windows failed for session: ${session_name}"
    return 1
  fi

  return 0
}

function _ghc_tmux_fallback_move_window_ {
  local source_window=$1
  local target_session_name=$2
  local target_window=$3
  local created_target=$4

  if [ "${created_target}" -eq 1 ]; then
    tmux move-window -k -s "${source_window}" -t "${target_window}"
  else
    tmux move-window -s "${source_window}" -t "${target_session_name}:"
  fi
}

function _ghc_tmux_move_window_ {
  local target_session_name=$1
  if [ -z "${target_session_name}" ]; then
    return 0
  fi

  local current_session_name
  local current_window_index
  local source_window
  local target_window
  local link_cmd
  local created_target=0

  current_session_name=$(tmux display-message -p '#{session_name}')
  current_window_index=$(tmux display-message -p '#{window_index}')
  source_window="${current_session_name}:${current_window_index}"

  if [ "${current_session_name}" = "${target_session_name}" ]; then
    return 0
  fi

  if ! tmux has-session -t "${target_session_name}" 2>/dev/null; then
    if ! tmux new-session -d -s "${target_session_name}" -e GHC_SKIP_INITIAL_WINDOW_RENAME=1; then
      _ghc_tmux_notify_ "failed to create session: ${target_session_name}"
      return 1
    fi
    created_target=1
  fi

  if [ "${created_target}" -eq 1 ]; then
    local base_index
    base_index=$(tmux display-message -p -t "${target_session_name}" '#{base-index}' 2>/dev/null)
    if [ -z "${base_index}" ]; then
      base_index=$(tmux show-options -gv base-index 2>/dev/null || echo 0)
    fi
    target_window="${target_session_name}:${base_index}"
    link_cmd=(tmux link-window -k -s "${source_window}" -t "${target_window}")
  else
    target_window="${target_session_name}:"
    link_cmd=(tmux link-window -s "${source_window}" -t "${target_window}")
  fi

  if ! "${link_cmd[@]}"; then
    _ghc_tmux_notify_ "link-window failed, fallback to move-window"
    if ! _ghc_tmux_fallback_move_window_ "${source_window}" "${target_session_name}" "${target_window}" "${created_target}"; then
      _ghc_tmux_notify_ "fallback move-window failed"
      return 1
    fi

    _ghc_tmux_renumber_session_ "${current_session_name}" || true

    if ! tmux switch-client -t "${target_session_name}"; then
      _ghc_tmux_notify_ "window moved, but failed to switch client"
    fi
    return 0
  fi

  if ! tmux switch-client -t "${target_session_name}"; then
    _ghc_tmux_notify_ "window moved, but failed to switch client"
  fi

  if ! tmux unlink-window -t "${source_window}"; then
    _ghc_tmux_notify_ "unlink-window failed, window may still exist in source session"
    return 1
  fi

  _ghc_tmux_renumber_session_ "${current_session_name}" || true
}

_ghc_tmux_move_window_ "$1"
