#! /usr/bin/env bash

function _ghc_tmux_popup_ {
	local current_session_name="_nvim_"
	local current_pane_path="$1"
	local default_window_name="${current_pane_path##*/}"
	local current_window_name="${2:-$default_window_name}"

	local popup_session_name="_popup@${current_session_name}"
	local popup_window_name="${current_window_name}"

	if [[ "${current_session_name}" = _popup@* ]]; then
		tmux detach-client
	else
		tmux has-session -t "${popup_session_name}" 2>/dev/null

		if [ $? != 0 ]; then
			tmux new-session -d -s "${popup_session_name}" -n "${popup_window_name}" -c "${current_pane_path}"
		else

			tmux select-window -t "${popup_session_name}:${popup_window_name}" 2>/dev/null

			if [ $? != 0 ]; then
				tmux new-window -t "${popup_session_name}" -n "${popup_window_name}" -c "${current_pane_path}"
				tmux select-window -t "${popup_session_name}:${popup_window_name}"
			fi
		fi
		tmux popup -d '#{pane_current_path}' -xC -yC -w80% -h80% -E "tmux new-session -A -s ${popup_session_name}"
	fi
}

if command -v tmux >/dev/null 2>&1; then
	_ghc_tmux_popup_ $1 $2
fi
