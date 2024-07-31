#!/bin/bash

# Get the name of the new session
new_session=$1

# Check if the session name starts with "_popup"
if [[ "${new_session}" == _popup@* ]]; then
  # Hide the status line
  tmux set-option status off
else
  # Show the status line
  tmux set-option status on
fi
