#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
crate_dir="$repo_dir/rust/ghc-tmux-status"
socket="ghc-tmux-running-indicator-test-$$"
tmp=$(mktemp -d /tmp/ghc-tmux-running-indicator-test.XXXXXX)

cleanup() {
  env -u TMUX tmux -L "$socket" kill-server 2>/dev/null || true
  rm -rf "$tmp"
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

assert_spinner_bell_prefix() {
  local value=$1
  local bell=$2
  local context=$3
  case "$value" in
    " ⠋ $bell" | " ⠴ $bell") ;;
    *) fail "$context: expected a padded session spinner and bell, got '$value'" ;;
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
beta_pane=$(tmux_server new-session -dP -F '#{pane_id}' -s beta -n main)
tmux_server source-file "$repo_dir/conf/variable.tmux.conf"
tmux_server source-file "$repo_dir/theme/catppuccin-mocha.tmux.conf"
tmux_server source-file "$repo_dir/conf/theme.tmux.conf"
terminal_title_format=$(
  sed -n \
    "s/^[[:space:]]*set[[:space:]][[:space:]]*-g[[:space:]][[:space:]]*set-titles-string[[:space:]][[:space:]]*'\(.*\)'$/\1/p" \
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
tmux_server select-pane -t "$beta_pane" -T '⠙ beta'
publish_session_states
assert_format "⠙ " beta:main '#{E:@GHC_WINDOW_PREFIX_FMT}' \
  "running window prefix in another session"
assert_format "0" alpha "$alpha_running_format" "target-session isolation"

# The same cached format changes with pane_title and sees non-active windows.
worker_pane=$(tmux_server new-window -dP -F '#{pane_id}' -t alpha -n worker)
tmux_server select-pane -t "$worker_pane" -T '⠸ alpha'
publish_session_states
assert_format "⠸ " alpha:worker '#{E:@GHC_WINDOW_PREFIX_FMT}' \
  "running worker window prefix"
assert_format "1" alpha "$alpha_running_format" "running session"
tmux_server set-option -g status-left "$alpha_running_prefix"
initial_session_prefix=$(tmux_server display-message -p -t alpha '#{T:status-left}')
assert_spinner_prefix "$initial_session_prefix" "running session prefix"

# Animation phase is derived from the existing one-second status clock. It
# advances without another scheduler sample or renderer/cache mutation.
advanced_session_prefix=$initial_session_prefix
for _ in $(seq 1 20); do
  sleep 0.1
  advanced_session_prefix=$(tmux_server display-message -p -t alpha '#{T:status-left}')
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

tmux_server select-pane -t "$worker_pane" -T 'idle'
publish_session_states
assert_format "" alpha:worker '#{E:@GHC_WINDOW_PREFIX_FMT}' "settled worker window"
assert_format "0" alpha "$alpha_running_format" "settled session"
assert_format "" alpha "$alpha_running_prefix" "settled session prefix"

# remain-on-exit panes retain their last title; pane_dead must suppress stale spinners.
dead_pane=$(tmux_server new-window -dP -F '#{pane_id}' -t alpha -n dead 'sleep 1')
tmux_server set-option -w -t alpha:dead remain-on-exit on
tmux_server select-pane -t "$dead_pane" -T '⠋ stale'
wait_for_dead_pane "$dead_pane"
publish_session_states
assert_format "" "$dead_pane" '#{E:@GHC_PANE_RUNNING_FMT}' "dead pane frame"
assert_format "" alpha:dead '#{E:@GHC_WINDOW_PREFIX_FMT}' "dead pane window"

# The configured current-window item preserves the original idle layout and
# prepends the live frame only while running. A theme-only reload also replaces
# any stale decorator format from before the reverse-color styling change.
tmux_server set-option -g @GHC_WINDOW_PREFIX_FMT 'stale-prefix'
tmux_server source-file "$repo_dir/conf/theme.tmux.conf"
assert_not_contains \
  "$(tmux_server show-option -gqv @GHC_WINDOW_PREFIX_FMT)" \
  'stale-prefix' "theme reload replaces cached window decorators"
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
# an independent decorator. Session items preserve both evidence types, while the
# terminal title keeps the same priority as window state.
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
beta_session_item_prefix="#{?#{==:#{@GHC_SL_SCHED_ACTIVE},1},#{?${beta_running_membership_format},${session_running_prefix},}#{?${beta_bell_membership_format}, ${bell_symbol},},}"
session_item_prefix=$(
  tmux_server display-message -p -t beta:alert "$beta_session_item_prefix"
)
assert_spinner_bell_prefix "$session_item_prefix" "$bell_symbol" \
  "session item shows running and bell states"
assert_format "4" beta:alert "#{w:${beta_session_item_prefix}}" \
  "combined session item prefix width"
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
for decorator in BELL ZOOM; do
  decorator_style=$(
    tmux_server display-message -p -t beta:alert \
      "#[fg=#{@GHC_SL_BG_WIN_ICON_${decorator}},bg=#{@GHC_SL_FG_WIN_ICON_${decorator}},reverse,bold]#{@GHC_SYM_WIN_${decorator}}"
  )
  assert_contains "$decorated_window_item_raw" "$decorator_style" \
    "inactive $decorator swaps colors with reverse"
done
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
assert_equal " $bell_symbol" \
  "$(tmux_server display-message -p -t beta:alert "$beta_session_item_prefix")" \
  "settled session item retains bell without spinner"
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

# Zoom keeps the active palette while reverse makes its background opaque.
tmux_server select-window -t beta:alert
active_window_item_raw=$(
  tmux_server display-message -p -t beta:alert \
    '#{T:window-status-current-format}'
)
active_zoom_style=$(
  tmux_server display-message -p -t beta:alert \
    '#[fg=#{@GHC_SL_BG_WIN_ACTIVE_ICON_ZOOM},bg=#{@GHC_SL_FG_WIN_ACTIVE_ICON_ZOOM},reverse,bold]#{@GHC_SYM_WIN_ZOOM}'
)
assert_contains "$active_window_item_raw" "$active_zoom_style" \
  "active zoom swaps colors with reverse"

tmux_server select-window -t beta:main
assert_format "1" beta:alert '#{window_last_flag}' "zoomed window is last"
last_window_item_raw=$(
  tmux_server display-message -p -t beta:alert '#{T:window-status-format}'
)
last_zoom_style=$(
  tmux_server display-message -p -t beta:alert \
    '#[fg=#{@GHC_SL_BG_WIN_LAST_ICON_ZOOM},bg=#{@GHC_SL_FG_WIN_LAST_ICON_ZOOM},reverse,bold]#{@GHC_SYM_WIN_ZOOM}'
)
assert_contains "$last_window_item_raw" "$last_zoom_style" \
  "last-window zoom swaps colors with reverse"

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

# With a valid lifecycle the driver hands its publication to the renderer, which
# carries it in the tick's first mutation queue; the driver itself only reads the
# scheduler snapshot. A HOME whose release path points at the freshly built debug
# binary keeps this check on the current sources.
cargo build --quiet --manifest-path "$crate_dir/Cargo.toml"
renderer_home="$tmp/home"
mkdir -p "$renderer_home/.config/tmux/rust/ghc-tmux-status/target/release"
ln -s "$crate_dir/target/debug/ghc-tmux-status" \
  "$renderer_home/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
real_tmux=$(command -v tmux)
mkdir -p "$tmp/bin"
cat >"$tmp/bin/tmux" <<'EOF'
#!/bin/sh
caller=$(ps -o comm= -p "$PPID" 2>/dev/null)
printf '%s\t%s\n' "${caller##*/}" "$*" >>"$GHC_TMUX_CALL_LOG"
case "$*" in *"${GHC_TMUX_FAIL_MATCH:-__never__}"*) exit 1 ;; esac
exec "$GHC_TMUX_REAL_TMUX" "$@"
EOF
chmod +x "$tmp/bin/tmux"
tmux_calls="$tmp/tmux-calls"

publish_through_driver() {
  : >"$tmux_calls"
  env \
    TMUX="$server_environment" \
    HOME="$renderer_home" \
    PATH="$tmp/bin:$PATH" \
    GHC_TMUX_REAL_TMUX="$real_tmux" \
    GHC_TMUX_CALL_LOG="$tmux_calls" \
    GHC_TMUX_STATUS_DRIVER_DELAY_SECONDS=0 \
    "$@" \
    "$repo_dir/script/status-scheduler.sh" \
    >/dev/null
}

count_calls() {
  local caller=$1
  local pattern=$2
  rg -c "^${caller}"$'\t'"${pattern}" "$tmux_calls" || echo 0
}

tmux_server set-option -s @GHC_SL_SCHED_ACTIVE 1 ';' \
  set-option -s @GHC_SL_SCHED_GEN 9 ';' \
  set-option -s @GHC_SL_METRIC_SCHED '9:1:9999999999:0' ';' \
  set-option -s @GHC_SL_HEARTBEAT_SCHED '9:1:9999999999:0'
tmux_server select-pane -t alpha:main -T '⠴ renderer-owned'
publish_through_driver
renderer_sample=$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)
assert_contains "$renderer_sample" "|R${alpha_id}|" "renderer-owned publication"
assert_equal "1" "$(count_calls bash '')" "driver tmux calls on the renderer path"
assert_equal "0" "$(count_calls bash 'run-shell -bC -d ')" "driver publication on the renderer path"
assert_equal "1" "$(count_calls ghc-tmux-status 'run-shell -bC -d ')" \
  "renderer publications per owned tick"

# A failed scheduler snapshot never starts the renderer, so the driver publishes.
publish_through_driver GHC_TMUX_FAIL_MATCH=@GHC_SL_HEARTBEAT_SCHED
driver_sample=$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)
assert_contains "$driver_sample" "|R${alpha_id}|" "driver publication after snapshot failure"
if [ "$driver_sample" = "$renderer_sample" ]; then
  fail "snapshot failure did not refresh the sample"
fi
assert_equal "1" "$(count_calls bash 'run-shell -bC -d ')" \
  "driver publications after snapshot failure"
assert_equal "0" "$(count_calls ghc-tmux-status '')" \
  "renderer calls after snapshot failure"

# Fake renderers model each side of the handoff: a renderer that predates the
# versioned request never acknowledges it, so a normal exit hands publication back
# to the driver; an acknowledgement transfers it for good; an abnormal exit keeps
# the generation fence and never falls back.
make_renderer_home() {
  local name=$1
  local body=$2
  local home="$tmp/renderer-$name"
  mkdir -p "$home/.config/tmux/rust/ghc-tmux-status/target/release"
  printf '#!/bin/sh\n%s\n' "$body" \
    >"$home/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
  chmod +x "$home/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
  printf '%s\n' "$home"
}

for legacy_status in 0 1; do
  legacy_home=$(make_renderer_home "legacy-$legacy_status" "exit $legacy_status")
  before=$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)
  publish_through_driver HOME="$legacy_home"
  after=$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)
  assert_contains "$after" "|R${alpha_id}|" "fallback after legacy renderer exit $legacy_status"
  if [ "$after" = "$before" ]; then
    fail "legacy renderer exit $legacy_status did not refresh the sample"
  fi
  assert_equal "1" "$(count_calls bash 'run-shell -bC -d ')" \
    "driver fallbacks after legacy renderer exit $legacy_status"
done

ack_home=$(make_renderer_home ack-only "printf '%s\\n' __GHC_SESSION_STATES_V2_TAKEN__")
before=$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)
publish_through_driver HOME="$ack_home"
assert_equal "$before" "$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)" \
  "acknowledged publication is never repeated by the driver"
assert_equal "0" "$(count_calls bash 'run-shell -bC -d ')" "driver publication after acknowledgement"

# Only the exact acknowledgement line transfers publication.
garbage_home=$(make_renderer_home garbage "printf '%s\\n' __GHC_SESSION_STATES_V1_TAKEN__")
publish_through_driver HOME="$garbage_home"
assert_equal "1" "$(count_calls bash 'run-shell -bC -d ')" \
  "driver fallback after an unrecognized acknowledgement"

# An ack that exists but cannot be fully read proves neither handoff outcome, so the
# driver never repeats a publication the renderer may already have made. The first
# renderer makes its acknowledged ack file unopenable; the second leaves a partial line.
unreadable_home=$(make_renderer_home unreadable-ack '
printf "%s\n" __GHC_SESSION_STATES_V2_TAKEN__
fields=${TMUX#*,}
chmod 000 "${TMPDIR:-/tmp}/ghc-tmux-status-scheduler-$(id -u)-${fields%%,*}.lock.ack.$PPID" \
  && : >"$GHC_TEST_ACK_BLOCKED"')
partial_home=$(make_renderer_home partial-ack "printf '%s' __GHC_SESSION_STATES_V2_TAKEN__")
ack_blocked="$tmp/ack-blocked"
for unknown_home in "$unreadable_home" "$partial_home"; do
  before=$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)
  publish_through_driver HOME="$unknown_home" GHC_TEST_ACK_BLOCKED="$ack_blocked"
  assert_equal "$before" "$(tmux_server show-option -sqv @GHC_SL_SESSION_STATES)" \
    "unknown acknowledgement keeps the sample: $unknown_home"
  assert_equal "0" "$(count_calls bash 'run-shell -bC -d ')" \
    "driver publication after an unknown acknowledgement: $unknown_home"
done
if [ ! -e "$ack_blocked" ]; then
  fail "unreadable-ack renderer did not block its ack file"
fi

panic_home=$(make_renderer_home panic "exit 101")
publish_through_driver HOME="$panic_home"
assert_equal "0" "$(count_calls bash 'run-shell -bC -d ')" "driver publication after abnormal exit"
assert_equal "0" "$(tmux_server show-option -sqv @GHC_SL_SCHED_ACTIVE)" \
  "abnormal renderer exit keeps the generation fence"
tmux_server set-option -s @GHC_SL_SCHED_ACTIVE 1

printf '%s\n' "running indicator integration: ok"
