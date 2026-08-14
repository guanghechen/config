#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
socket="ghc-tmux-running-indicator-test-$$"

cleanup() {
  env -u TMUX tmux -L "$socket" kill-server 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

tmux_server() {
  env -u TMUX tmux -L "$socket" "$@"
}

assert_equal() {
  local expected=$1
  local actual=$2
  local context=$3
  if [ "$actual" != "$expected" ]; then
    fail "$context: expected '$expected', got '$actual'"
  fi
}

assert_format() {
  local expected=$1
  local target=$2
  local format=$3
  local context=$4
  assert_equal "$expected" \
    "$(tmux_server display-message -p -t "$target" "$format")" "$context"
}

assert_contains() {
  local value=$1
  local expected=$2
  local context=$3
  if [[ "$value" != *"$expected"* ]]; then
    fail "$context: expected '$value' to contain '$expected'"
  fi
}

assert_not_contains() {
  local value=$1
  local rejected=$2
  local context=$3
  if [[ "$value" = *"$rejected"* ]]; then
    fail "$context: expected '$value' not to contain '$rejected'"
  fi
}

assert_spinner_prefix() {
  local value=$1
  local context=$2
  case "$value" in
    " ⠋" | " ⠴") ;;
    *) fail "$context: expected a padded session spinner, got '$value'" ;;
  esac
}

assert_spinner_title() {
  local value=$1
  local title=$2
  local context=$3
  case "$value" in
    "⠋ $title" | "⠴ $title") ;;
    *) fail "$context: expected a session spinner before '$title', got '$value'" ;;
  esac
}

strip_styles() {
  sed -E 's/#\[[^]]*\]//g'
}

wait_for_dead_pane() {
  local target=$1
  local state
  for _ in $(seq 1 100); do
    state=$(tmux_server display-message -p -t "$target" '#{pane_dead}')
    if [ "$state" = "1" ]; then
      return 0
    fi
    sleep 0.02
  done
  fail "pane $target did not become dead"
}

publish_session_states() {
  local ttl_seconds=${1:-12}
  env \
    TMUX="$server_environment" \
    GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS=0 \
    GHC_TMUX_STATUS_SESSION_STATE_TTL_SECONDS="$ttl_seconds" \
    "$repo_dir/script/status-scheduler.sh" \
    >/dev/null
}

tmux_server -f /dev/null new-session -d -s alpha -n main
tmux_server new-session -d -s beta -n main
tmux_server source-file "$repo_dir/conf/variable.tmux.conf"
terminal_title_format=$(
  sed -n \
    "s/^[[:space:]]*set[[:space:]]\+-g[[:space:]]\+set-titles-string[[:space:]]\+'\(.*\)'$/\1/p" \
    "$repo_dir/tmux.conf"
)
if [ -z "$terminal_title_format" ]; then
  fail "set-titles-string format not found in tmux.conf"
fi
tmux_server set-option -g set-titles-string "$terminal_title_format"
tmux_server set-option -g @GHC_SL_MODE 02 ';' \
  set-option -s @GHC_SL_SCHED_ACTIVE 1
server_environment=$(tmux_server display-message -p '#{socket_path},#{pid},0')

session_running_prefix="#{=2:#{E:@GHC_SESSION_RUNNING_PREFIX_FMT}}"
assert_format "2" alpha "#{w:${session_running_prefix}}" \
  "session running prefix width"

alpha_id=$(tmux_server display-message -p -t alpha '#{session_id}')
beta_id=$(tmux_server display-message -p -t beta '#{session_id}')
alpha_running_membership_format="#{m:*|R${alpha_id}|*,#{@GHC_SL_SESSION_STATES}}"
alpha_running_format="#{&&:#{==:#{@GHC_SL_SCHED_ACTIVE},1},${alpha_running_membership_format}}"
alpha_running_prefix="#{?${alpha_running_format},${session_running_prefix},}"
beta_running_membership_format="#{m:*|R${beta_id}|*,#{@GHC_SL_SESSION_STATES}}"
beta_bell_membership_format="#{m:*|B${beta_id}|*,#{@GHC_SL_SESSION_STATES}}"

publish_session_states
assert_format "" alpha:main '#{E:@GHC_WINDOW_PREFIX_FMT}' "idle window"
assert_format "0" alpha "$alpha_running_format" "idle session"
assert_format "" alpha "$alpha_running_prefix" "idle session prefix"

# A running pane in another session must not leak into alpha's aggregate.
tmux_server select-pane -t beta:main.0 -T '⠙ beta'
publish_session_states
assert_format "⠙ " beta:main '#{E:@GHC_WINDOW_PREFIX_FMT}' \
  "running window prefix in another session"
assert_format "0" alpha "$alpha_running_format" "target-session isolation"

# The same cached format changes with pane_title and sees non-active windows.
tmux_server new-window -d -t alpha -n worker
tmux_server select-pane -t alpha:worker.0 -T '⠸ alpha'
publish_session_states
assert_format "⠸ " alpha:worker '#{E:@GHC_WINDOW_PREFIX_FMT}' \
  "running worker window prefix"
assert_format "1" alpha "$alpha_running_format" "running session"
initial_session_prefix=$(
  tmux_server display-message -p -t alpha "$alpha_running_prefix"
)
assert_spinner_prefix "$initial_session_prefix" "running session prefix"

# Animation phase is derived from the existing one-second status clock. It
# advances without another scheduler sample or renderer/cache mutation.
advanced_session_prefix=$initial_session_prefix
for _ in $(seq 1 20); do
  sleep 0.1
  advanced_session_prefix=$(
    tmux_server display-message -p -t alpha "$alpha_running_prefix"
  )
  if [ "$advanced_session_prefix" != "$initial_session_prefix" ]; then
    break
  fi
done
assert_spinner_prefix "$advanced_session_prefix" "advanced session spinner prefix"
if [ "$advanced_session_prefix" = "$initial_session_prefix" ]; then
  fail "session spinner did not advance from '$initial_session_prefix'"
fi

# Missing or malformed animation format degrades to no marker.
session_prefix_format=$(
  tmux_server show-option -gqv @GHC_SESSION_RUNNING_PREFIX_FMT
)
tmux_server set-option -gu @GHC_SESSION_RUNNING_PREFIX_FMT
assert_format "" alpha "$alpha_running_prefix" \
  "missing session spinner format"
tmux_server set-option -g @GHC_SESSION_RUNNING_PREFIX_FMT '#{broken'
assert_format "" alpha "$alpha_running_prefix" \
  "malformed session spinner format"
tmux_server set-option -g @GHC_SESSION_RUNNING_PREFIX_FMT \
  "$session_prefix_format"

tmux_server select-pane -t alpha:worker.0 -T 'idle'
publish_session_states
assert_format "" alpha:worker '#{E:@GHC_WINDOW_PREFIX_FMT}' "settled worker window"
assert_format "0" alpha "$alpha_running_format" "settled session"
assert_format "" alpha "$alpha_running_prefix" "settled session prefix"

# remain-on-exit panes retain their last title; pane_dead must suppress stale spinners.
tmux_server new-window -d -t alpha -n dead 'sleep 1'
tmux_server set-option -w -t alpha:dead remain-on-exit on
tmux_server select-pane -t alpha:dead.0 -T '⠋ stale'
wait_for_dead_pane alpha:dead.0
publish_session_states
assert_format "" alpha:dead.0 '#{E:@GHC_PANE_RUNNING_FMT}' "dead pane frame"
assert_format "" alpha:dead '#{E:@GHC_WINDOW_PREFIX_FMT}' "dead pane window"

# The configured current-window item preserves the original idle layout and
# prepends the live frame only while running.
tmux_server source-file "$repo_dir/theme/catppuccin-mocha.tmux.conf"
tmux_server source-file "$repo_dir/conf/theme.tmux.conf"
tmux_server select-pane -t beta:main -T 'idle'
idle_window_item=$(
  tmux_server display-message -p -t beta:main \
    '#{T:window-status-current-format}' | strip_styles
)
assert_contains "$idle_window_item" "main | " "idle window item matches baseline layout"

tmux_server select-pane -t beta:main -T '⠧ beta'
running_window_item=$(
  tmux_server display-message -p -t beta:main \
    '#{T:window-status-current-format}' | strip_styles
)
assert_contains "$running_window_item" "⠧ main | " "running window frame before title"

# Window items consume pane_title directly, so a frame change needs no scheduler
# sample or Rust cache rewrite.
tmux_server select-pane -t beta:main -T '⠇ beta'
spun_window_item=$(
  tmux_server display-message -p -t beta:main \
    '#{T:window-status-current-format}' | strip_styles
)
assert_contains "$spun_window_item" "⠇ main | " "advanced spinner frame before title"
assert_not_contains "$spun_window_item" "⠧" "stale window spinner frame"
publish_session_states

# Window state is mutually exclusive: spinner wins over bell, while zoom remains
# an independent decorator. Session state follows the same priority in terminal title.
tmux_server set-window-option -g monitor-bell on
tmux_server set-option -g bell-action any
tmux_server new-window -d -t beta -n alert \
  "sleep 0.3; printf '\\007'; sleep 10"
alert_pane=$(tmux_server display-message -p -t beta:alert '#{pane_id}')
tmux_server select-pane -t "$alert_pane" -T 'idle alert'
tmux_server split-window -d -t beta:alert 'sleep 10'
tmux_server resize-pane -Z -t "$alert_pane"
window_bell_flag=0
for _ in $(seq 1 20); do
  window_bell_flag=$(
    tmux_server display-message -p -t beta:alert '#{window_bell_flag}'
  )
  if [ "$window_bell_flag" = "1" ]; then
    break
  fi
  sleep 0.1
done
assert_equal "1" "$window_bell_flag" "alert window bell flag"
bell_symbol=$(tmux_server show-option -gqv @GHC_SYM_WIN_BELL)
zoom_symbol=$(tmux_server show-option -gqv @GHC_SYM_WIN_ZOOM)
publish_session_states
assert_format "1" beta "$beta_running_membership_format" \
  "sample contains running beta session"
assert_format "1" beta "$beta_bell_membership_format" \
  "sample contains belling beta session"
decorated_window_item=$(
  tmux_server display-message -p -t beta:alert \
    '#{T:window-status-format}' | strip_styles
)
decorated_window_item_raw=$(
  tmux_server display-message -p -t beta:alert \
    '#{T:window-status-format}'
)
assert_contains "$decorated_window_item" \
  "$bell_symbol $zoom_symbol alert" \
  "bell-only window state before zoom and title"
assert_contains "$decorated_window_item_raw" "nobold]alert" \
  "inactive window state restores non-bold title style"
terminal_title_before=$(
  tmux_server display-message -p -t beta:alert '#{pane_title}'
)
terminal_title=$(
  tmux_server display-message -p -t beta:alert '#{T:set-titles-string}'
)
assert_spinner_title "$terminal_title" "beta:alert" \
  "running session suppresses bell in terminal title"
assert_not_contains "$terminal_title" "$bell_symbol" \
  "running terminal title omits lower-priority bell"
assert_equal "$terminal_title_before" \
  "$(tmux_server display-message -p -t beta:alert '#{pane_title}')" \
  "terminal title does not rewrite pane title"

tmux_server select-pane -t "$alert_pane" -T '⠋ alert'
decorated_window_item=$(
  tmux_server display-message -p -t beta:alert \
    '#{T:window-status-format}' | strip_styles
)
assert_contains "$decorated_window_item" \
  "⠋ $zoom_symbol alert" \
  "window spinner wins over bell before zoom and title"
assert_not_contains "$decorated_window_item" "$bell_symbol" \
  "running window omits lower-priority bell"

tmux_server select-pane -t beta:main -T 'idle'
tmux_server select-pane -t "$alert_pane" -T 'idle'
publish_session_states
assert_format "0" beta "$beta_running_membership_format" \
  "settled beta session is not running"
assert_format "1" beta "$beta_bell_membership_format" \
  "settled beta session retains bell"
terminal_title=$(
  tmux_server display-message -p -t beta:alert '#{T:set-titles-string}'
)
assert_equal "$bell_symbol beta:alert" "$terminal_title" \
  "settled session falls back to bell in terminal title"
assert_not_contains \
  "$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)" \
  "|R${beta_id}|" \
  "bell and zoom do not imply running"
assert_contains \
  "$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)" \
  "|B${beta_id}|" \
  "bell evidence remains in sampled session state"

# A delayed expiry may clear only its own sample, never a newer refresh.
tmux_server select-pane -t alpha:main -T '⠴ expiring'
publish_session_states 0.3
assert_format "1" alpha "$alpha_running_format" "sampled running session"
old_sample=$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)
sleep 0.1
publish_session_states 0.8
refreshed_sample=$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)
if [ "$old_sample" = "$refreshed_sample" ]; then
  fail "running-session sample token did not refresh"
fi
sleep 0.3
assert_equal "$refreshed_sample" \
  "$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)" \
  "old delayed timer preserves refreshed sample"
sleep 0.6
assert_equal "" \
  "$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)" \
  "refreshed running-session sample expires"
assert_format "" alpha "$alpha_running_prefix" "expired session prefix"

publish_session_states
refreshed_session_prefix=$(
  tmux_server display-message -p -t alpha "$alpha_running_prefix"
)
assert_spinner_prefix "$refreshed_session_prefix" "refreshed session prefix"
tmux_server set-option -s @GHC_SL_SCHED_ACTIVE 0
assert_format "" alpha "$alpha_running_prefix" \
  "fenced scheduler hides session marker"
assert_format "⠴ alpha:main" alpha:main '#{T:set-titles-string}' \
  "inactive scheduler falls back to live session state in terminal title"
publish_session_states
assert_equal "" \
  "$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)" \
  "inactive lifecycle clears sampled sessions"

printf '%s\n' "running indicator integration: ok"
