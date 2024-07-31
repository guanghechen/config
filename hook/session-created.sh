#! /usr/bin/env bash

function _ghc_tmux_hook_session_created {
  # Get the name of the new session
  local new_session_name=$1

  # Check if the session name starts with "_popup"
  if [[ "${new_session_name}" == _popup@* ]]; then
    # Hide the status line
    tmux set-option status off
  else
    # Show the status line
    tmux set-option status on
  fi
}

_ghc_tmux_hook_session_created "$1"
