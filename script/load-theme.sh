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
    'session-renamed[40]' \
    'session-window-changed[40]'
}

function _ghc_tmux_unset_status_layout_hooks_ {
  local layout_hook
  for layout_hook in $(_ghc_tmux_status_layout_hooks_); do
    tmux set-hook -gu "$layout_hook" 2>/dev/null || true
  done
}

# The renderer writes LAYOUT (rows / status-format / lengths / @GHC_SL_LAYOUT) per
# session, and per-session options shadow the global ones. Switching modes (or any
# reload) must clear those overrides on EVERY session, else a session left at
# `status 2` keeps two rows under status01. We only undo the renderer's two-row
# narrow (`status 2` -> `on`); on/off ownership is left untouched, so popup/agent
# sessions stay `off` without needing any name-class knowledge here. All sessions'
# resets are folded into one tmux invocation; `-q` keeps a session that vanishes
# mid-reload from aborting the rest of the chain.
function _ghc_tmux_reset_per_session_layout_ {
  local -a args=()
  local session_id session_status
  while IFS=$'\t' read -r session_id session_status; do
    if [ "${#args[@]}" -gt 0 ]; then
      args+=(';')
    fi
    args+=(set -q -t "$session_id" -u '@GHC_SL_LAYOUT' ';' \
           set -q -t "$session_id" -u 'status-format' ';' \
           set -q -t "$session_id" -u 'status-left-length' ';' \
           set -q -t "$session_id" -u 'status-right-length')
    if [ "$session_status" = "2" ]; then
      args+=(';' set -q -t "$session_id" status on)
    fi
  done < <(tmux list-sessions -F '#{session_id}'$'\t''#{status}' 2>/dev/null)

  if [ "${#args[@]}" -gt 0 ]; then
    tmux "${args[@]}" 2>/dev/null || true
  fi
}

# A reload token needs uniqueness, not arithmetic ordering. Epoch + process id +
# a per-call nonce avoids both overlapping reload races and same-shell rapid
# reload reuse while remaining an unsigned integer accepted by the renderer CLI.
function _ghc_tmux_new_generation_ {
  printf '%s%05d%04d\n' \
    "$(date +%s)" "$(( $$ % 100000 ))" "$(( RANDOM % 10000 ))"
}

# The server option is authoritative for atomic `if-shell -F` guards: server
# options win format lookup even when a session has a same-name override. The
# global copy is retained only to expire pre-upgrade renderer chains that still
# read `show -gqv`. Both writes share one tmux command queue.
function _ghc_tmux_bump_heartbeat_generation_ {
  local generation
  generation=$(_ghc_tmux_new_generation_)
  tmux set -s @GHC_SL_HEARTBEAT_GEN "$generation" ';' \
       set -g @GHC_SL_HEARTBEAT_GEN "$generation"
  printf '%s\n' "$generation"
}

# Same generation-guard mechanism as the heartbeat, for the unified metric sampler
# chain. Must match ghc-tmux-status METRIC_SAMPLE_GENERATION_OPTION.
function _ghc_tmux_bump_metric_generation_ {
  local generation
  generation=$(_ghc_tmux_new_generation_)
  tmux set -s @GHC_SL_METRIC_GEN "$generation" ';' \
       set -g @GHC_SL_METRIC_GEN "$generation"
  printf '%s\n' "$generation"
}

# Expire pre-unified CPU-only sampler chains after upgrade/reload.
function _ghc_tmux_bump_legacy_cpu_generation_ {
  local generation
  generation=$(( $(tmux show -gqv @GHC_SL_CPU_GEN 2>/dev/null || echo 0) + 1 ))
  tmux set -g @GHC_SL_CPU_GEN "$generation"
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
  _ghc_tmux_reset_per_session_layout_

  # Expire any prior heartbeat/metric chains; only the status02 branch starts new
  # ones, so switching to status01 leaves bumped generations with no live chain.
  local heartbeat_generation
  heartbeat_generation=$(_ghc_tmux_bump_heartbeat_generation_)
  local metric_generation
  metric_generation=$(_ghc_tmux_bump_metric_generation_)
  _ghc_tmux_bump_legacy_cpu_generation_

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
      # Global single-row baseline; the renderer overrides per session (on/2). Any
      # session without a per-session override falls back to one row, never two.
      tmux set -g status on

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
        tmux set-hook -g 'session-window-changed[40]' "run-shell '$status_renderer apply window-changed'"

        if ! "$status_renderer" apply theme-loaded; then
          _ghc_tmux_unset_status_layout_hooks_
          _ghc_tmux_load_status01_ "$status_position"
          tmux display-message "Rust status renderer failed; fallback to status01" 2>/dev/null || true
        else
          tmux run-shell -b -d 30 "'$status_renderer' heartbeat $heartbeat_generation"
          # Seed fixed-width placeholders so metric pills never render blank values
          # before the first publishable sample; keep live values across reloads.
          if [ -z "$(tmux show -gqv @GHC_CPU_NOW 2>/dev/null)" ]; then
            tmux set -g @GHC_CPU_NOW " 0"
          fi
          if [ -z "$(tmux show -gqv @GHC_MEM_NOW 2>/dev/null)" ]; then
            tmux set -g @GHC_MEM_NOW " 0"
          fi
          if [ -z "$(tmux show -gqv @GHC_NET_NOW 2>/dev/null)" ]; then
            tmux set -g @GHC_NET_NOW "↓0B ↑0B"
          fi
          # The status line redraws every second; the renderer self-reschedules
          # metric sampling every METRIC_RESAMPLE_INTERVAL_SECONDS.
          tmux run-shell -b "'$status_renderer' metrics-sample $metric_generation"
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
