#!/bin/bash

# Get the direction from the command line argument (prev or next)
direction=$1

# Get the name of the current session
current_session_name=$(tmux display-message -p '#S')

# Get the list of sessions, excluding those that start with "_popup"
if [[ "${current_session_name}" == _popup@* ]]; then
  sessions=$(tmux list-sessions -F "#{session_name}" | grep "^_popup@")
else
  sessions=$(tmux list-sessions -F "#{session_name}" | grep -v "^_popup@")
fi

# Find the index of the current session in the list of sessions
index=0
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
target_session_name=$(echo "$sessions" | sed -n "$((target_index + 1))p")

# Switch to the target session
if [ "${current_session_name}" != "${target_session_name}" ]; then
  tmux switch-client -t "${target_session_name}"
fi
