#! /usr/bin/env bash

function _ghc_tmux_same_session_group_ {
  local current_session_name=$1
  local session_name=$2

  if [[ "${current_session_name}" == _popup@* ]]; then
    [[ "${session_name}" == _popup@* ]]
    return
  fi

  if [[ "${current_session_name}" =~ ^(claude|codex|gemini)-[0-9A-Fa-f]+$ ]]; then
    [[ "${session_name}" =~ ^(claude|codex|gemini)-[0-9A-Fa-f]+$ ]]
    return
  fi

  if [[ "${current_session_name}" =~ ^G([0-9]+)- ]]; then
    [[ "${session_name}" == "G${BASH_REMATCH[1]}-"* ]]
    return
  fi

  if [[ "${session_name}" == _popup@* ]]; then
    return 1
  fi

  if [[ "${session_name}" =~ ^(claude|codex|gemini)-[0-9A-Fa-f]+$ ]]; then
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
  local display_mode=${8:-index}
  local prefix_symbol=${9:-}
  local prefix_sep_left=${10:-}

  local -a session_ids=()
  local -a session_names=()
  local session_separator=$'\t'
  local session_id
  local session_name
  while IFS="${session_separator}" read -r session_id session_name; do
    if _ghc_tmux_same_session_group_ "${current_session_name}" "${session_name}"; then
      session_ids+=("${session_id}")
      session_names+=("${session_name}")
    fi
  done < <(tmux list-sessions -F "#{session_id}${session_separator}#{session_name}" 2>/dev/null)

  if [ "${display_mode}" == "count" ]; then
    printf '%s\n' "${#session_names[@]}"
    return
  fi

  if [ "${#session_names[@]}" -le 1 ]; then
    return
  fi

  if [ "${display_mode}" == "kitty" ] && [ -n "${prefix_symbol}" ]; then
    printf '#[fg=%s]%s#[fg=%s,bg=%s,bold]%s #[default] ' \
      "${current_bg}" "${prefix_sep_left}" \
      "${current_fg}" "${current_bg}" "${prefix_symbol}"
  fi

  local index=1
  local offset=0
  for session_name in "${session_names[@]}"; do
    local session_id=${session_ids[$offset]}

    if [ "${display_mode}" == "kitty" ]; then
      if [ "${index}" -gt 1 ]; then
        printf ' '
      fi

      if [ "${session_name}" == "${current_session_name}" ]; then
        local left_sep=$sep_left
        if [ "${index}" -eq 1 ]; then
          left_sep=
        fi

        printf '#[fg=%s,bg=%s]#[range=session|%s]%s#[fg=%s,bg=%s,bold] %s | %s #[fg=%s,bg=%s]%s#[norange]#[default]' \
          "${current_bg}" "${status_bg}" "${session_id}" "${left_sep}" \
          "${current_fg}" "${current_bg}" "${session_name}" "${index}" \
          "${current_bg}" "${status_bg}" "${sep_right}"
      else
        printf '#[%s]#[range=session|%s]%s | %s#[norange]#[default]' \
          "${normal_style}" "${session_id}" "${session_name}" "${index}"
      fi
    elif [ "${session_name}" == "${current_session_name}" ]; then
      printf '#[fg=%s,bg=%s,bold]#[range=session|%s]%s%s%s#[norange]#[default]' \
        "${current_fg}" "${current_bg}" "${session_id}" "${sep_left}" "${index}" "${sep_right}"
    else
      printf '#[%s]#[range=session|%s]%s%s%s#[norange]#[default]' \
        "${normal_style}" "${session_id}" "${sep_left}" "${index}" "${sep_right}"
    fi

    index=$((index + 1))
    offset=$((offset + 1))
  done
}

_ghc_tmux_session_status_ "$@"
