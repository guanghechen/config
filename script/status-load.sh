#! /usr/bin/env bash

function _ghc_tmux_status_load_ {
  # Determine platform
  # if [[ "$(uname)" == "Darwin" ]]; then
  #   platform="mac"
  # elif grep -qEi "(Microsoft|WSL)" /proc/version; then
  #   platform="wsl"
  # else
  #   platform="nix"
  # fi

  local status_mode=$(tmux show -gqv @GHC_SL_MODE)
  if [ -z "$status_mode" ]; then
    status_mode="01"
    tmux set -g @GHC_SL_MODE "$status_mode"
  fi

  local panestatus_mode=$(tmux show -gqv @GHC_PSL_MODE)
  if [ -z "$panestatus_mode" ]; then
    panestatus_mode="01"
    tmux set -g @GHC_PSL_MODE "$panestatus_mode"
  fi

  if [ "$status_mode" == "00" ]; then
    tmux set-option -s status off
    tmux set-option -s status-position top
  elif [ "$status_mode" == "01" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme/status01.tmux.conf"
    tmux set-option -s status on
    tmux set-option -s status-position top
  elif [ "$status_mode" == "02" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme/status02.tmux.conf"
    tmux set-option -s status on
    tmux set-option -s status-position top
  elif [ "$status_mode" == "10" ]; then
    tmux set-option -s status off
    tmux set-option -s status-position bottom
  elif [ "$status_mode" == "11" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme/status01.tmux.conf"
    tmux set-option -s status on
    tmux set-option -s status-position bottom
  elif [ "$status_mode" == "12" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme/status02.tmux.conf"
    tmux set-option -s status on
    tmux set-option -s status-position bottom
  fi

  if [ "$panestatus_mode" == "00" ]; then
    tmux set-option -s pane-border-status off
  elif [ "$panestatus_mode" == "01" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme/panestatus01.tmux.conf"
    tmux set-option -s pane-border-status top
  elif [ "$panestatus_mode" == "02" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme/panestatus02.tmux.conf"
    tmux set-option -s pane-border-status top
  elif [ "$panestatus_mode" == "10" ]; then
    tmux set-option -s pane-border-status off
  elif [ "$panestatus_mode" == "11" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme/panestatus01.tmux.conf"
    tmux set-option -s pane-border-status bottom
  elif [ "$panestatus_mode" == "12" ]; then
    tmux source-file "$HOME/.config/tmux/conf/theme/panestatus02.tmux.conf"
    tmux set-option -s pane-border-status bottom
  fi
}

_ghc_tmux_status_load_
