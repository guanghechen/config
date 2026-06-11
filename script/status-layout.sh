#! /usr/bin/env bash

function _ghc_tmux_status_layout_ {
  local mode
  local current_layout
  local option_name
  local option_value
  while read -r option_name option_value; do
    case "$option_name" in
      "@GHC_SL_MODE") mode=$option_value ;;
      "@GHC_SL_LAYOUT") current_layout=$option_value ;;
    esac
  done < <(tmux show -gq 2>/dev/null)

  local width
  width=$(tmux display-message -p '#{client_width}' 2>/dev/null)

  local current_status
  current_status=$(tmux show -qv status)

  if [ "$mode" != "02" ] && [ "$mode" != "12" ]; then
    return 0
  fi

  local wide_threshold=200
  if ! [[ "$width" =~ ^[0-9]+$ ]]; then
    width=$wide_threshold
  fi

  local position="top"
  if [ "$mode" == "12" ]; then
    position="bottom"
  fi

  local layout="narrow"
  if [ "$width" -ge "$wide_threshold" ]; then
    layout="wide"
  fi

  local layout_key="${mode}:${layout}"
  local target_status="2"
  if [ "$layout" == "wide" ]; then
    target_status="on"
  fi

  if [ "$current_status" == "off" ]; then
    return 0
  fi

  if [ "$current_layout" == "$layout_key" ] && [ "$current_status" == "$target_status" ]; then
    return 0
  fi

  if [ "$layout" == "wide" ]; then
    tmux set -g @GHC_SL_LAYOUT "$layout_key" \; \
      set -g status-position "$position" \; \
      set -g status-justify centre \; \
      set -g status on \; \
      set status on \; \
      set -gu status-format
  else
    tmux set -g @GHC_SL_LAYOUT "$layout_key" \; \
      set -g status-position "$position" \; \
      set -g status-justify centre \; \
      set -g status 2 \; \
      set status 2 \; \
      set -g 'status-format[0]' '#{E:@GHC_SL_STATUS02_SESSION_FORMAT}' \; \
      set -g 'status-format[1]' '#{E:@GHC_SL_STATUS02_CURRENT_FORMAT}'
  fi

  tmux refresh-client -S 2>/dev/null || true
}

_ghc_tmux_status_layout_
