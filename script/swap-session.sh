#! /usr/bin/env bash

function _ghc_tmux_status_renderer_bin_ {
  local status_renderer="$HOME/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
  if [ ! -x "$status_renderer" ]; then
    return 0
  fi

  local help_text
  help_text=$("$status_renderer" help 2>/dev/null || true)
  if [[ "$help_text" == *"session swap"* ]]; then
    printf '%s\n' "$status_renderer"
  fi
}

function _ghc_tmux_swap_session_ {
  local direction=${1:-next}
  local status_renderer
  status_renderer=$(_ghc_tmux_status_renderer_bin_)
  if [ -z "$status_renderer" ]; then
    tmux display-message "Rust status renderer missing; cannot swap sessions"
    return 0
  fi

  "$status_renderer" session swap "$direction"
}

_ghc_tmux_swap_session_ "$@"
