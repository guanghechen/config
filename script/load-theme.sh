#! /usr/bin/env bash

function _ghc_tmux_set_status_ {
  local status_value=$1
  local current_status
  current_status=$(tmux show -qv status)

  tmux set -g status "$status_value"
  if [ "$current_status" != "off" ]; then
    tmux set status "$status_value"
  fi
}


function _ghc_tmux_status_renderer_bin_ {
  local status_renderer="$HOME/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
  if [ -x "$status_renderer" ]; then
    printf '%s\n' "$status_renderer"
  fi
}

function _ghc_tmux_status_layout_hooks_ {
  printf '%s\n' \
    'client-resized[40]' \
    'client-session-changed[40]' \
    'session-created[40]' \
    'session-closed[40]' \
    'session-renamed[40]'
}

function _ghc_tmux_unset_status_layout_hooks_ {
  local layout_hook
  for layout_hook in $(_ghc_tmux_status_layout_hooks_); do
    tmux set-hook -gu "$layout_hook" 2>/dev/null || true
  done
}

function _ghc_tmux_load_status01_ {
  local status_position=$1

  _ghc_tmux_set_status_ on
  tmux set -g status-justify centre
  tmux set -g status-position "$status_position"
  tmux source "$HOME/.config/tmux/conf/theme/status01.tmux.conf"
}

function _ghc_tmux_normalize_status_mode_ {
  local status_mode=$1

  case "$status_mode" in
    "" | "03") echo "01" ;;
    "04") echo "02" ;;
    "13") echo "11" ;;
    "14") echo "12" ;;
    "01" | "02" | "11" | "12") echo "$status_mode" ;;
    *) echo "01" ;;
  esac
}

function _ghc_tmux_load_theme_ {
  local status_mode
  status_mode=$(_ghc_tmux_normalize_status_mode_ "$(tmux show -gqv @GHC_SL_MODE)")
  tmux set -g @GHC_SL_MODE "$status_mode"

  local panestatus_mode
  panestatus_mode=$(tmux show -gqv @GHC_PSL_MODE)
  if [ -z "$panestatus_mode" ]; then
    panestatus_mode="01"
    tmux set -g @GHC_PSL_MODE "$panestatus_mode"
  fi

  _ghc_tmux_unset_status_layout_hooks_
  tmux set -gu status-format 2>/dev/null || true
  tmux set -gu @GHC_SL_LAYOUT 2>/dev/null || true

  local status_position="top"
  if [ "$status_mode" == "11" ] || [ "$status_mode" == "12" ]; then
    status_position="bottom"
  fi

  case "$status_mode" in
    "01" | "11")
      _ghc_tmux_load_status01_ "$status_position"
      ;;
    "02" | "12")
      local status_renderer
      status_renderer=$(_ghc_tmux_status_renderer_bin_)
      tmux set -g status-justify centre
      tmux set -g status-position "$status_position"

      if [ -z "$status_renderer" ]; then
        _ghc_tmux_load_status01_ "$status_position"
        tmux display-message "Rust status renderer missing; fallback to status01" 2>/dev/null || true
      else
        tmux source "$HOME/.config/tmux/conf/theme/status02.tmux.conf"
        tmux set-hook -g 'client-resized[40]' "run-shell '$status_renderer apply client-resized'"
        tmux set-hook -g 'client-session-changed[40]' "run-shell '$status_renderer apply session-changed'"
        tmux set-hook -g 'session-created[40]' "run-shell '$status_renderer apply session-created'"
        tmux set-hook -g 'session-closed[40]' "run-shell '$status_renderer apply session-closed'"
        tmux set-hook -g 'session-renamed[40]' "run-shell '$status_renderer apply session-renamed'"

        if ! "$status_renderer" apply theme-loaded; then
          _ghc_tmux_unset_status_layout_hooks_
          _ghc_tmux_load_status01_ "$status_position"
          tmux display-message "Rust status renderer failed; fallback to status01" 2>/dev/null || true
        fi
      fi
      ;;
  esac

  if [ "$panestatus_mode" == "01" ]; then
    tmux set -g pane-border-status top
    tmux source "$HOME/.config/tmux/conf/theme/panestatus01.tmux.conf"
  elif [ "$panestatus_mode" == "02" ]; then
    tmux set -g pane-border-status top
    tmux source "$HOME/.config/tmux/conf/theme/panestatus02.tmux.conf"
  elif [ "$panestatus_mode" == "11" ]; then
    tmux set -g pane-border-status bottom
    tmux source "$HOME/.config/tmux/conf/theme/panestatus01.tmux.conf"
  elif [ "$panestatus_mode" == "12" ]; then
    tmux set -g pane-border-status bottom
    tmux source "$HOME/.config/tmux/conf/theme/panestatus02.tmux.conf"
  fi

  if [ -f "$HOME/.config/tmux/local/theme.tmux.conf" ]; then
    tmux source "$HOME/.config/tmux/local/theme.tmux.conf"
  fi
  tmux source "$HOME/.config/tmux/conf/theme.tmux.conf"
  tmux refresh-client -S 2>/dev/null || true
}

_ghc_tmux_load_theme_
