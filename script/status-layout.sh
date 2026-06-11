#! /usr/bin/env bash

function _ghc_tmux_status_layout_ {
  local mode
  mode=$(tmux show -gqv @GHC_SL_MODE)

  if [ "$mode" != "02" ] && [ "$mode" != "12" ]; then
    return 0
  fi

  local wide_threshold=200
  local width
  width=$(tmux display-message -p '#{client_width}' 2>/dev/null)
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

  local current_layout
  current_layout=$(tmux show -gqv @GHC_SL_LAYOUT)

  local current_status
  current_status=$(tmux show -qv status)
  if [ "$current_status" == "off" ]; then
    return 0
  fi

  if [ "$current_layout" == "$layout_key" ] && [ "$current_status" == "$target_status" ]; then
    return 0
  fi

  tmux set -g @GHC_SL_LAYOUT "$layout_key"
  tmux set -g status-position "$position"
  tmux set -g status-justify centre

  if [ "$layout" == "wide" ]; then
    tmux set -g status on
    tmux set status on
    tmux set -gu status-format
  else
    tmux set -g status 2
    tmux set status 2
    tmux set -g 'status-format[0]' '#{E:@GHC_SL_STATUS02_SESSION_FORMAT}'
    tmux set -g 'status-format[1]' '#{E:@GHC_SL_STATUS02_CURRENT_FORMAT}'
  fi

  tmux refresh-client -S 2>/dev/null || true
}

_ghc_tmux_status_layout_
