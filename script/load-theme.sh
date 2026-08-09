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


function _ghc_tmux_status_driver_bin_ {
  local status_driver="$HOME/.config/tmux/script/status-scheduler.sh"
  if [ -x "$status_driver" ]; then
    printf '%s\n' "$status_driver"
  fi
}


function _ghc_tmux_recover_status_scheduler_lock_ {
  local status_driver
  status_driver=$(_ghc_tmux_status_driver_bin_)
  if [ -n "$status_driver" ]; then
    "$status_driver" --recover >/dev/null 2>&1 || true
  fi
}

function _ghc_tmux_status_layout_hooks_ {
  printf '%s\n' \
    'client-attached[40]' \
    'client-detached[40]' \
    'client-resized[40]' \
    'client-session-changed[40]' \
    'session-created[40]' \
    'session-closed[40]' \
    'session-renamed[40]' \
    'session-window-changed[40]'
}

# Layout hooks are reconcile notifications, not part of the triggering tmux
# transaction. A failed background job must stay silent because tmux turns job
# output or a non-zero exit into view-mode; the next lifecycle event retries.
function _ghc_tmux_set_status_layout_hook_ {
  local layout_hook=$1
  local event=$2
  local status_renderer=$3
  tmux set-hook -g "$layout_hook" \
    "run-shell -b '$status_renderer apply $event >/dev/null 2>&1 || true'"
}

function _ghc_tmux_defer_status_bootstrap_ {
  tmux set-hook -g 'session-created[40]' \
    "run-shell -b 'bash \"$HOME/.config/tmux/script/load-theme.sh\" >/dev/null 2>&1 || true'"
}

function _ghc_tmux_unset_status_layout_hooks_ {
  local layout_hook
  for layout_hook in $(_ghc_tmux_status_layout_hooks_); do
    tmux set-hook -gu "$layout_hook" 2>/dev/null || true
  done
}

# The renderer writes both render cache and LAYOUT (rows / status-format / lengths /
# @GHC_SL_LAYOUT) per session. Switching modes (or any reload) must clear those
# overrides on EVERY session, else stale cache shadows the next global fallback and
# a session left at `status 2` keeps two rows under status01. We only undo the
# renderer's two-row narrow (`status 2` -> `on`); on/off ownership is left untouched,
# so popup/agent sessions stay `off` without name-class knowledge here. All resets
# are folded into one tmux invocation; `-q` tolerates a session vanishing mid-reload.
function _ghc_tmux_reset_per_session_layout_ {
  local -a args=()
  local session_id session_status
  while IFS=$'\t' read -r session_id session_status; do
    if [ "${#args[@]}" -gt 0 ]; then
      args+=(';')
    fi
    args+=(set -q -t "$session_id" -u '@GHC_SL_LAYOUT' ';' \
           set -q -t "$session_id" -u '@GHC_SL_RENDER_KEY' ';' \
           set -q -t "$session_id" -u '@GHC_SL_STATUS02_LEFT' ';' \
           set -q -t "$session_id" -u '@GHC_SL_STATUS02_RIGHT' ';' \
           set -q -t "$session_id" -u '@GHC_SL_STATUS02_SESSION_FORMAT' ';' \
           set -q -t "$session_id" -u '@GHC_SL_STATUS02_CURRENT_FORMAT' ';' \
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
# reload reuse while remaining an unsigned integer accepted by scheduler state.
function _ghc_tmux_new_generation_ {
  printf '%s%05d%04d\n' \
    "$(date +%s)" "$(( $$ % 100000 ))" "$(( RANDOM % 10000 ))"
}

_GHC_TMUX_STATUS_FENCED_GENERATION=""

# Fence every prior status02 scheduler before changing formats. ACTIVE is the
# first mutation; GEN fences task commits; RENDER_REV fences ordinary hook commits.
# A retry covers an ambiguous client failure after server commit.
function _ghc_tmux_fence_scheduler_ {
  local attempt generation
  for attempt in 1 2; do
    generation=$(_ghc_tmux_new_generation_)
    if tmux set -s @GHC_SL_SCHED_ACTIVE 0 ';' \
            set -s @GHC_SL_SCHED_GEN "$generation" ';' \
            set -s @GHC_SL_RENDER_REV "fenced:$generation"; then
      _GHC_TMUX_STATUS_FENCED_GENERATION=$generation
      return 0
    fi
  done
  tmux set -s @GHC_SL_SCHED_ACTIVE 0 2>/dev/null || true
  return 1
}

# Only the loader that owns the current lifecycle generation may activate the
# scheduler. A superseded loader returns 2 so it can stop without fencing the
# newer owner during fallback cleanup.
function _ghc_tmux_activate_status_scheduler_ {
  local generation=$1
  local status_mode=$2
  local outcome
  if ! [[ "$generation" =~ ^[0-9]+$ ]] \
    || ! [[ "$status_mode" =~ ^(02|12)$ ]]; then
    return 1
  fi
  outcome=$(tmux if-shell -F \
    "#{&&:#{==:#{@GHC_SL_SCHED_GEN},#{l:$generation}},#{&&:#{==:#{@GHC_SL_SCHED_ACTIVE},0},#{==:#{@GHC_SL_MODE},#{l:$status_mode}}}}" \
    'set -s @GHC_SL_SCHED_ACTIVE 1 ; display-message -p __GHC_SCHED_ACTIVATED__' \
    'display-message -p __GHC_SCHED_SUPERSEDED__' \
    2>/dev/null) || return 1
  case "$outcome" in
    "__GHC_SCHED_ACTIVATED__") return 0 ;;
    "__GHC_SCHED_SUPERSEDED__") return 2 ;;
    *) return 1 ;;
  esac
}

function _ghc_tmux_load_status01_ {
  local status_position=$1

  _ghc_tmux_set_status_ on
  tmux set -g status-justify centre
  tmux set -g status-position "$status_position"
  tmux source "$HOME/.config/tmux/conf/theme/status01.tmux.conf"
}

function _ghc_tmux_status02_fallback_ {
  local status_position=$1
  local message=$2

  _ghc_tmux_unset_status_layout_hooks_
  _ghc_tmux_fence_scheduler_ >/dev/null 2>&1 || true
  _ghc_tmux_reset_per_session_layout_
  _ghc_tmux_load_status01_ "$status_position"
  tmux display-message "$message" 2>/dev/null || true
}

function _ghc_tmux_normalize_status_mode_ {
  local status_mode=$1

  case "$status_mode" in
    "") echo "02" ;;
    "03") echo "01" ;;
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
  local status_position="top"
  if [ "$status_mode" == "11" ] || [ "$status_mode" == "12" ]; then
    status_position="bottom"
  fi

  if ! _ghc_tmux_fence_scheduler_; then
    tmux display-message "Status scheduler initialization failed; fallback to status01" 2>/dev/null || true
    if [ "$status_position" = "bottom" ]; then
      status_mode="11"
    else
      status_mode="01"
    fi
    tmux set -g @GHC_SL_MODE "$status_mode" 2>/dev/null || true
  fi
  _ghc_tmux_recover_status_scheduler_lock_

  # Lifecycle is fenced before the first renderer-owned reset, so an in-flight
  # hook cannot publish stale status02 options over the selected mode.
  tmux set -gu status-format 2>/dev/null || true
  tmux set -gu @GHC_SL_LAYOUT 2>/dev/null || true
  _ghc_tmux_reset_per_session_layout_

  case "$status_mode" in
    "01" | "11")
      _ghc_tmux_load_status01_ "$status_position"
      ;;
    "02" | "12")
      local status_renderer
      status_renderer=$(_ghc_tmux_status_renderer_bin_)
      local status_driver
      status_driver=$(_ghc_tmux_status_driver_bin_)
      tmux set -g status-justify centre
      tmux set -g status-position "$status_position"
      # Global single-row baseline; the renderer overrides per session (on/2). Any
      # session without a per-session override falls back to one row, never two.
      tmux set -g status on

      if [ -z "$status_renderer" ] || [ -z "$status_driver" ]; then
        _ghc_tmux_load_status01_ "$status_position"
        tmux display-message "Status renderer or scheduler driver missing; fallback to status01" 2>/dev/null || true
      elif [ -z "$(tmux list-sessions -F '#{session_id}' 2>/dev/null)" ]; then
        # A fresh server loads tmux.conf before creating its first session, so
        # status02 has no render context yet. Keep the usable fallback and let
        # the first session retry through this lifecycle writer exactly once.
        _ghc_tmux_load_status01_ "$status_position"
        _ghc_tmux_defer_status_bootstrap_
      else
        tmux source "$HOME/.config/tmux/conf/theme/status02.tmux.conf"
        # Attach/detach change the attached-width set, so they share the
        # client-resized event kind.
        _ghc_tmux_set_status_layout_hook_ 'client-attached[40]' client-resized "$status_renderer"
        _ghc_tmux_set_status_layout_hook_ 'client-detached[40]' client-resized "$status_renderer"
        _ghc_tmux_set_status_layout_hook_ 'client-resized[40]' client-resized "$status_renderer"
        _ghc_tmux_set_status_layout_hook_ 'client-session-changed[40]' session-changed "$status_renderer"
        _ghc_tmux_set_status_layout_hook_ 'session-created[40]' session-created "$status_renderer"
        _ghc_tmux_set_status_layout_hook_ 'session-closed[40]' session-closed "$status_renderer"
        _ghc_tmux_set_status_layout_hook_ 'session-renamed[40]' session-renamed "$status_renderer"
        _ghc_tmux_set_status_layout_hook_ 'session-window-changed[40]' window-changed "$status_renderer"

        local bootstrap_generation="$_GHC_TMUX_STATUS_FENCED_GENERATION"
        if ! "$status_renderer" apply theme-loaded "$bootstrap_generation"; then
          # A newer loader owns the lifecycle now. This stale loader must stop;
          # falling back would rotate the new owner's generation and undo it.
          # A failed generation read cannot prove supersession, so it falls
          # through to fail-closed status01 cleanup.
          local current_generation
          if current_generation=$(tmux show -sqv @GHC_SL_SCHED_GEN 2>/dev/null) \
            && [ "$current_generation" != "$bootstrap_generation" ]; then
            return 0
          fi
          # Guarded replay can fail after committing a prefix of the plan. Fence
          # workers before rolling every renderer-owned local option back.
          _ghc_tmux_status02_fallback_ "$status_position" \
            "Rust status renderer failed; fallback to status01"
        else
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
          # status-left/status-format[0] own the tmux-managed #() driver. CAS +
          # leases inside the renderer deduplicate per-client invocations.
          local activation_status
          _ghc_tmux_activate_status_scheduler_ \
            "$bootstrap_generation" "$status_mode"
          activation_status=$?
          case "$activation_status" in
            0) ;;
            # A newer loader owns lifecycle state and will finish initialization.
            2) return 0 ;;
            *)
              _ghc_tmux_status02_fallback_ "$status_position" \
                "Status scheduler activation failed; fallback to status01"
              ;;
          esac
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
