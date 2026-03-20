#! /usr/bin/env bash

function _ghc_tmux_hook_session_created {
  local new_session_name=$1
  local skip_initial_window_rename=0
  local skip_flag

  skip_flag=$(tmux show-environment -t "${new_session_name}" GHC_SKIP_INITIAL_WINDOW_RENAME 2>/dev/null || true)
  if [[ "${skip_flag}" == "GHC_SKIP_INITIAL_WINDOW_RENAME=1" ]]; then
    skip_initial_window_rename=1
  fi

  # Avoid leaking the helper flag into session environment for future panes.
  tmux set-environment -r -t "${new_session_name}" GHC_SKIP_INITIAL_WINDOW_RENAME 2>/dev/null || true

  if [[ "${new_session_name}" == _popup@* ]]; then
    tmux set-option -t "${new_session_name}" status off
    tmux set-option -t "${new_session_name}" detach-on-destroy on
  elif [[ "${new_session_name}" =~ ^(claude|codex|gemini)-[0-9a-f]+$ ]]; then
    tmux set-option -t "${new_session_name}" status off
    tmux set-option -t "${new_session_name}" detach-on-destroy on
  elif [[ "${new_session_name}" =~ ^G[0-9]+- ]]; then
    tmux set-option -t "${new_session_name}" status on
    tmux set-option -t "${new_session_name}" detach-on-destroy off
  else
    tmux set-option -t "${new_session_name}" status on
    if [ "${skip_initial_window_rename}" -eq 0 ]; then
      tmux rename-window -t "${new_session_name}:1" "${new_session_name}" 2>/dev/null || true
    fi
  fi
}

_ghc_tmux_hook_session_created "$1"
