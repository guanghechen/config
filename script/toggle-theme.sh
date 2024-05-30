#! /usr/bin/env bash

function _ghc_tmux_toggle_theme_ {
	local current_theme=$(tmux show-environment -g TMUX_THEME 2>/dev/null | cut -d '=' -f 2)
	if [ "$current_theme" == "LIGHTEN" ]; then
		tmux set-environment -g TMUX_THEME DARKEN
	elif [ "$current_theme" == "DARKEN" ]; then
		tmux set-environment -g TMUX_THEME LIGHTEN
	else
		tmux set-environment -g TMUX_THEME DARKEN
	fi
	tmux source-file ~/.config/tmux/tmux.conf
}

_ghc_tmux_toggle_theme_
