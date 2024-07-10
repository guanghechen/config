#! /usr/bin/env bash

function _ghc_tmux_popup_ {
	local current_session_name=$(tmux display-message -p -F "#{session_name}")
	local current_window_name=$(tmux display-message -p -F "#{window_name}")
	local current_pane_path=$(tmux display-message -p -F "#{pane_current_path}")
	local popup_session_name="_popup@${current_session_name}"
	local popup_window_name="${current_window_name}"

	if [[ "${current_session_name}" = _popup@* ]]; then
		tmux detach-client
	else
		# Check if popup session already exists
		tmux has-session -t "${popup_session_name}" 2>/dev/null

		if [ $? != 0 ]; then
			# Create new popup session and window if it doesn't exist
			tmux new-session -d -s "${popup_session_name}" -n "${popup_window_name}" -c "${current_pane_path}"
		else
			# Ensure we select the correct window in the popup session
			tmux select-window -t "${popup_session_name}:${popup_window_name}" 2>/dev/null

			if [ $? != 0 ]; then
				tmux new-window -t "${popup_session_name}" -n "${popup_window_name}" -c "${current_pane_path}"
				tmux select-window -t "${popup_session_name}:${popup_window_name}"
			fi
		fi

		# Launch the popup with desired settings, since the tmux popup could block following scripts,
		# so run it in the background and sleep 300ms to run the remain codes.
		tmux popup -d '#{pane_current_path}' -xC -yC -w80% -h80% -E "tmux new-session -A -s ${popup_session_name}" &

		sleep 0.3 # Sleep 300ms.

		# Check if there's exactly one pane in the popup window.
		local popup_pane_count=$(tmux list-panes | wc -l)
		if [ "${popup_pane_count}" -eq 1 ]; then
			local current_popup_pane_path=$(tmux display-message -p -F "#{pane_current_path}")

			# Check if the current pane path differs from the popup pane path.
			if [ "${current_pane_path}" != "${current_popup_pane_path}" ]; then
				current_pane_path=$(printf '%q' "$current_pane_path") # Escape the path.

				local popup_active_pane_id=$(tmux display-message -p -t "${popup_session_name}:${popup_window_name}" "#{pane_id}")
				tmux send-keys -t "${popup_active_pane_id}" "cd ${current_pane_path}" C-m
			fi
		fi
	fi
}

_ghc_tmux_popup_
