#! /usr/bin/env bash

function _ghc_tmux_session_status_ {
  local current_session_name=$1
  local current_fg=${2:-default}
  local current_bg=${3:-default}
  local normal_style=${4:-default}
  local status_bg=${5:-default}
  local sep_left=${6:-}
  local sep_right=${7:-}

  local index=1
  local session_name
  while IFS= read -r session_name; do
    if [ "${index}" -gt 1 ]; then
      printf ' '
    fi

    if [ "${session_name}" == "${current_session_name}" ]; then
      printf '#[fg=%s,bg=%s]%s#[fg=%s,bg=%s,bold]%s#[fg=%s,bg=%s]%s#[default]' \
        "${current_bg}" "${status_bg}" "${sep_left}" \
        "${current_fg}" "${current_bg}" "${index}" \
        "${current_bg}" "${status_bg}" "${sep_right}"
    else
      printf '#[%s]%s#[default]' "${normal_style}" "${index}"
    fi

    index=$((index + 1))
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
}

_ghc_tmux_session_status_ "$@"
