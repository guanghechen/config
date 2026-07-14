#! /usr/bin/env bash


function _ghc_tmux_status_renderer_bin_ {
  local status_renderer="$HOME/.config/tmux/rust/ghc-tmux-status/target/release/ghc-tmux-status"
  if [ ! -x "$status_renderer" ]; then
    return 0
  fi

  local help_text
  help_text=$("$status_renderer" help 2>/dev/null || true)
  if [[ "$help_text" == *"session focus"* ]]; then
    printf '%s\n' "$status_renderer"
  fi
}

function _ghc_tmux_focus_session_ {
  local direction=$1
  local status_renderer
  status_renderer=$(_ghc_tmux_status_renderer_bin_)
  if [ -n "$status_renderer" ]; then
    "$status_renderer" session focus "$direction"
    return $?
  fi

  local current_session_name
  current_session_name="$(tmux display-message -p '#S')"

  if [[ "${current_session_name}" == _popup@* ]]; then
    sessions=$(tmux list-sessions -F '#{session_name}' | grep '^_popup@')
  elif [[ "${current_session_name}" =~ ^(claude|codex|gemini)-[0-9A-Fa-f]+$ ]]; then
    sessions=$(tmux list-sessions -F '#{session_name}' | grep -E '^(claude|codex|gemini)-[0-9A-Fa-f]+$')
  elif [[ "${current_session_name}" =~ ^G([0-9]+)- ]]; then
    local group_prefix="G${BASH_REMATCH[1]}-"
    sessions=$(tmux list-sessions -F '#{session_name}' | grep "^${group_prefix}")
  else
    sessions=$(tmux list-sessions -F '#{session_name}' | grep -v '^_popup@' | grep -v -E '^(claude|codex|gemini)-[0-9A-Fa-f]+$' | grep -v -E '^G[0-9]+-')
  fi

  if [[ "${direction}" =~ ^[0-9]$ ]]; then
    if [ "${direction}" == "0" ]; then
      tmux display-message "No session at index ${direction}"
      return 0
    fi

    local target_session_name
    target_session_name=$(echo "${sessions}" | sed -n "${direction}p")

    if [ -z "${target_session_name}" ]; then
      tmux display-message "No session at index ${direction}"
      return 0
    fi

    if [ "${current_session_name}" != "${target_session_name}" ]; then
      tmux switch-client -t "${target_session_name}"
    fi

    return 0
  fi

  # Find the index of the current session in the list of sessions
  local index=0
  while IFS= read -r session; do
    if [[ "$session" == "$current_session_name" ]]; then
      break
    fi
    index=$((index + 1))
  done <<<"$sessions"

  local session_count
  session_count=$(echo "$sessions" | wc -l)

  # Calculate the index of the target session based on the direction
  if [ "$direction" == "prev" ]; then
    target_index=$(((index - 1 + session_count) % session_count))
  elif [ "$direction" == "next" ]; then
    target_index=$(((index + 1) % session_count))
  else
    echo "Invalid direction: $direction"
    exit 1
  fi

  # Get the name of the target session
  local target_session_name
  target_session_name=$(echo "$sessions" | sed -n "$((target_index + 1))p")

  # Switch to the target session
  if [ "${current_session_name}" != "${target_session_name}" ]; then
    tmux switch-client -t "${target_session_name}"
  fi
}

_ghc_tmux_focus_session_ "$1"
