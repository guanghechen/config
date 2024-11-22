#! /usr/bin/env bash

function _ghc_tmux_theme_reload_ {
  tmux source-file "$HOME/.config/tmux/conf/variable.tmux.conf"
  tmux refresh-client -S
}

_ghc_tmux_theme_reload_
