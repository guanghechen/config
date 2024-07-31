#! /usr/bin/env bash

function _ghc_tmux_focus_session_ {
  local direction=$1
  local current_session_name=$(tmux display-message -p '#S')

  if [[ "${current_session_name}" == _popup@* ]]; then
    sessions=$(tmux list-sessions -F "#{session_name}" | grep "^_popup@")
  else
    sessions=$(tmux list-sessions -F "#{session_name}" | grep -v "^_popup@")
  fi

  # Find the index of the current session in the list of sessions
  local index=0
  for session in $sessions; do
    if [ "$session" == "$current_session_name" ]; then
      break
    fi
    index=$((index + 1))
  done

  # Calculate the index of the target session based on the direction
  if [ "$direction" == "prev" ]; then
    target_index=$(((index - 1 + $(echo "$sessions" | wc -l)) % $(echo "$sessions" | wc -l)))
  elif [ "$direction" == "next" ]; then
    target_index=$(((index + 1) % $(echo "$sessions" | wc -l)))
  else
    echo "Invalid direction: $direction"
    exit 1
  fi

  # Get the name of the target session
  local target_session_name=$(echo "$sessions" | sed -n "$((target_index + 1))p")

  # Switch to the target session
  if [ "${current_session_name}" != "${target_session_name}" ]; then
    tmux switch-client -t "${target_session_name}"
  fi
}

_ghc_tmux_focus_session_ "$1"
