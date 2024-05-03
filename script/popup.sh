#! /usr/bin/env bash

function _ghc_tmux_popup_ {
  local popup_session_name="_popup"
  local popup_window_name=$(tmux display-message -p -F "#{window_name}")

  if [ "$(tmux display-message -p -F "#{session_name}")" = "${popup_session_name}" ];then
    tmux detach-client
  else
    tmux has-session -t "${popup_session_name}" 2> /dev/null

    if [ $? != 0 ]; then
      tmux new-session -d -s "${popup_session_name}"
      tmux new-window -t "${popup_session_name}" -n "${popup_window_name}"
    else

      tmux select-window -t "${popup_session_name}:${popup_window_name}" 2> /dev/null

      if [ $? != 0 ]; then
        tmux new-window -t "${popup_session_name}" -n "${popup_window_name}"
      tmux select-window -t "${popup_session_name}:${popup_window_name}"
      fi
    fi
    tmux popup -d '#{pane_current_path}' -xC -yC -w80% -h80% -E "tmux new-session -A -s ${popup_session_name}"
  fi
}

_ghc_tmux_popup_
