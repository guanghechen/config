#! /usr/bin/env bash

function _ghc_tmux_hook_session_created {
  # Get the name of the new session
  local new_session_name=$1

  # Check if the session name starts with "_popup" or is the agent session
  if [[ "${new_session_name}" == _popup@* ]] || [[ "${new_session_name}" == __agent__ ]]; then
    # Hide the status line and enable detach-on-destroy
    tmux set-option -t "${new_session_name}" status off
    tmux set-option -t "${new_session_name}" detach-on-destroy on
  else
    # Show the status line
    tmux set-option -t "${new_session_name}" status on
    tmux rename-window -t "${new_session_name}:1" "${new_session_name}" 2>/dev/null || true
  fi
}

_ghc_tmux_hook_session_created "$1"
