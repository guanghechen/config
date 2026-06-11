#! /usr/bin/env bash

function _ghc_tmux_same_session_group_ {
  local current_session_name=$1
  local session_name=$2

  if [[ "${current_session_name}" == _popup@* ]]; then
    [[ "${session_name}" == _popup@* ]]
    return
  fi

  if [[ "${current_session_name}" =~ ^(claude|codex|gemini)-[0-9a-f]+$ ]]; then
    [[ "${session_name}" =~ ^(claude|codex|gemini)-[0-9a-f]+$ ]]
    return
  fi

  if [[ "${current_session_name}" =~ ^G([0-9]+)- ]]; then
    [[ "${session_name}" == "G${BASH_REMATCH[1]}-"* ]]
    return
  fi

  if [[ "${session_name}" == _popup@* ]]; then
    return 1
  fi

  if [[ "${session_name}" =~ ^(claude|codex|gemini)-[0-9a-f]+$ ]]; then
    return 1
  fi

  if [[ "${session_name}" =~ ^G[0-9]+- ]]; then
    return 1
  fi

  return 0
}

function _ghc_tmux_session_status_ {
  local current_session_name=$1
  local current_fg=${2:-default}
  local current_bg=${3:-default}
  local normal_style=${4:-default}
  local status_bg=${5:-default}
  local sep_left=${6:-}
  local sep_right=${7:-}

  local -a session_names=()
  local session_name
  while IFS= read -r session_name; do
    if _ghc_tmux_same_session_group_ "${current_session_name}" "${session_name}"; then
      session_names+=("${session_name}")
    fi
  done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)

  if [ "${#session_names[@]}" -le 1 ]; then
    return
  fi

  local index=1
  for session_name in "${session_names[@]}"; do
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
  done
}

_ghc_tmux_session_status_ "$@"
