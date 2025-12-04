#! /usr/bin/env bash

function _ghc_tmux_hook_session_created {
  local new_session_name=$1

  if [[ "${new_session_name}" == _popup@* ]]; then
    tmux set-option -t "${new_session_name}" status off
    tmux set-option -t "${new_session_name}" detach-on-destroy on
  elif [[ "${new_session_name}" =~ ^(claude|codex|gemini)-[0-9a-f]+$ ]]; then
    tmux set-option -t "${new_session_name}" status off
    tmux set-option -t "${new_session_name}" detach-on-destroy on
  else
    tmux set-option -t "${new_session_name}" status on
    tmux rename-window -t "${new_session_name}:1" "${new_session_name}" 2>/dev/null || true
  fi
}

_ghc_tmux_hook_session_created "$1"
