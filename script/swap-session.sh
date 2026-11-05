#! /usr/bin/env bash

function _ghc_tmux_swap_session_ {
  local direction=$1
  local status_renderer="$HOME/.config/tmux/bin/ghc-tmux-status"
  if [ ! -x "$status_renderer" ]; then
    tmux display-message "Session swap unavailable" >/dev/null 2>&1 || true
    return 0
  fi

  if "$status_renderer" session swap "$direction" >/dev/null 2>&1; then
    return 0
  fi

  # run-shell turns command output or a non-zero exit into view-mode, which
  # captures all pane input. Swap failure must remain a status message.
  tmux display-message "Session swap failed" >/dev/null 2>&1 || true
}

_ghc_tmux_swap_session_ "$1"
