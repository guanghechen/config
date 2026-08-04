#! /usr/bin/env bash

# Cycles the manual rows override (@GHC_SL_ROWS) for the adaptive status line:
#   auto -> single row (1) -> two rows (2) -> auto
# `auto` keeps the width/session-count heuristic; `1`/`2` pin the row count on
# every screen (this is what lets a wide client show two rows). The override only
# takes visible effect in adaptive modes (@GHC_SL_MODE 02/12); in the static
# modes (01/11) the value is stored and applies once adaptive mode is active.

function _ghc_tmux_status_renderer_bin_ {
  local status_renderer="$HOME/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
  if [ -x "$status_renderer" ]; then
    printf '%s\n' "$status_renderer"
  fi
}

function _ghc_tmux_toggle_rows_ {
  local direction="${1:-forward}"
  local rows
  rows=$(tmux show -gqv @GHC_SL_ROWS)
  rows=${rows:-2}

  local next
  case "$direction" in
    "backward")
      case "$rows" in
        "1") next="auto" ;;
        "2") next="1" ;;
        *)   next="2" ;;
      esac
      ;;
    *)
      case "$rows" in
        "1") next="2" ;;
        "2") next="auto" ;;
        *)   next="1" ;;
      esac
      ;;
  esac

  tmux set -g @GHC_SL_ROWS "$next"

  # Re-resolve per-session layouts against the new override. `apply` reads the
  # fresh snapshot and is a safe no-op outside adaptive modes.
  local status_renderer
  status_renderer=$(_ghc_tmux_status_renderer_bin_)
  if [ -n "$status_renderer" ]; then
    "$status_renderer" apply manual-apply 2>/dev/null || true
  fi
  tmux refresh-client -S 2>/dev/null || true

  local label
  case "$next" in
    "1") label="1 row (forced)" ;;
    "2") label="2 rows (forced)" ;;
    *)   label="auto" ;;
  esac
  tmux display-message "Status rows: $label" 2>/dev/null || true
}

_ghc_tmux_toggle_rows_ "$@"
