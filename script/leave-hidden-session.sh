#! /usr/bin/env bash

# A destroyed session moves its clients to the most recently active remaining
# session, which can be a status-off popup or agent session. A client landed there
# that way has no last session (switch-client records one) and is not new (an
# attach is), so move it to the most recently active visible session; with none
# left it stays. Keep the pattern in sync with the session policy in tmux.conf.
readonly hidden_session_pattern='^(_popup@|(claude|codex|gemini)-[0-9A-Fa-f]+$)'

function _ghc_tmux_leave_hidden_session_ {
  local client=$1
  local name session last created activity target
  # list-clients expands each client's own fields; display-message may report
  # another client of the same session. A non-whitespace separator keeps an
  # empty last session as its own field.
  while IFS=$'\037' read -r name session last created activity; do
    [ "$name" = "$client" ] && break
  done < <(tmux list-clients -F \
    '#{client_name}'$'\037''#{session_name}'$'\037''#{client_last_session}'$'\037''#{client_created}'$'\037''#{session_activity}')
  if [ "$name" != "$client" ]; then
    return 0
  fi
  if ! [[ "$session" =~ $hidden_session_pattern ]] || [ -n "$last" ] \
    || ! [[ "$created" =~ ^[0-9]+$ && "$activity" =~ ^[0-9]+$ ]] \
    || (( created + 2 >= activity )); then
    return 0
  fi

  target=$(tmux list-sessions -F '#{session_activity}'$'\t''#{session_id}'$'\t''#{session_name}' \
    | awk -F '\t' -v hidden="$hidden_session_pattern" '$3 !~ hidden' \
    | sort -rn | awk -F '\t' 'NR == 1 { print $2 }')
  if [ -n "$target" ]; then
    tmux switch-client -c "$client" -t "$target"
  fi
}

_ghc_tmux_leave_hidden_session_ "$1"
