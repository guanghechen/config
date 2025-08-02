#! /usr/bin/env bash

function _ghc_tmux_load_theme_ {
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
    tmux set -g status off
  elif [ "$status_mode" == "01" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/status01.tmux.conf"
    tmux set -g status-position top
    tmux set -g status-justify left
    tmux set -g status on
  elif [ "$status_mode" == "02" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/status02.tmux.conf"
    tmux set -g status-position top
    tmux set -g status-justify left
    tmux set -g status on
  elif [ "$status_mode" == "03" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/status03.tmux.conf"
    tmux set -g status-position top
    tmux set -g status-justify centre
    tmux set -g status on
  elif [ "$status_mode" == "10" ]; then
    tmux set -g status off
  elif [ "$status_mode" == "11" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/status01.tmux.conf"
    tmux set -g status-position bottom
    tmux set -g status-justify left
    tmux set -g status on
  elif [ "$status_mode" == "12" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/status02.tmux.conf"
    tmux set -g status-position bottom
    tmux set -g status-justify left
    tmux set -g status on
  elif [ "$status_mode" == "13" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/status03.tmux.conf"
    tmux set -g status-position bottom
    tmux set -g status-justify centre
    tmux set -g status on
  fi

  if [ "$panestatus_mode" == "00" ]; then
    tmux set -g pane-border-status off
  elif [ "$panestatus_mode" == "01" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/panestatus01.tmux.conf"
    tmux set -g pane-border-status top
  elif [ "$panestatus_mode" == "02" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/panestatus02.tmux.conf"
    tmux set -g pane-border-status top
  elif [ "$panestatus_mode" == "10" ]; then
    tmux set -g pane-border-status off
  elif [ "$panestatus_mode" == "11" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/panestatus01.tmux.conf"
    tmux set -g pane-border-status bottom
  elif [ "$panestatus_mode" == "12" ]; then
    tmux source "$HOME/.config/tmux/conf/theme/panestatus02.tmux.conf"
    tmux set -g pane-border-status bottom
  fi

  if [ -f "$HOME/.config/tmux/local/theme.tmux.conf" ]; then
    tmux source "$HOME/.config/tmux/local/theme.tmux.conf"
  fi
  tmux source "$HOME/.config/tmux/conf/theme.tmux.conf"
  tmux refresh-client -S
}

_ghc_tmux_load_theme_
