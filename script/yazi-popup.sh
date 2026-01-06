#!/bin/bash

# Unset TMUX to prevent Yazi from using tmux passthrough mode
unset TMUX
unset TMUX_PANE
unset TERM_PROGRAM
unset TERM_PROGRAM_VERSION

# Start fish in interactive mode
# Run yazi in fish_prompt, then kill fish process
exec fish -i -C '
set -g fish_greeting
function fish_prompt
    yazi 2>/dev/null
    kill %self
end
'
