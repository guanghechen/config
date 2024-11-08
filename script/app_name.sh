#!/usr/bin/env bash

function _ghc_tmux_app_name_ {
  local pane_tty=$1
  local app_name=$(ps -o comm= -t "${pane_tty}" | rg -o '[\w-]+' | tail -1)

  if [ -d "/proc" ]; then
    if [ "${app_name}" = "nvim" ]; then
      local app_pid=$(ps -o pid= -t "${pane_tty}" | rg -o '\d+' | tail -1)
      local nvim_app_name=$(cat "/proc/${app_pid}/environ" 2>/dev/null | rg -ao 'NVIM_APPNAME=nvim-([\w-]+)' -r '$1')
    fi
  fi

  if [ -n "${nvim_app_name}" ]; then
    echo "${nvim_app_name}"
  else
    echo "${app_name}"
  fi
}

_ghc_tmux_app_name_ "$1"
