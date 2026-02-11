#!/usr/bin/env bash

# Default settings (checked in)
export GHC_APP_EDITION_NODE=24
export GHC_APP_EDITION_NVIM=manual
export GHC_APP_EDITION_TMUX=latest
export GHC_APP_PYTHON_ENV=lemon
export GHC_EDITION=nix
export GHC_THEME=vsc-dark-modern

# Source local overrides if exists
_ghc_env_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$_ghc_env_dir/setting.local.bash" ] && source "$_ghc_env_dir/setting.local.bash"
unset _ghc_env_dir
