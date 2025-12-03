#! /usr/bin/env bash

function _ghc_tmux_hook_client_session_changed {
  local session_name=$1

  if [[ "${session_name}" == __agent__ ]]; then
    tmux refresh-client -S
  fi
}

_ghc_tmux_hook_client_session_changed "$1"
