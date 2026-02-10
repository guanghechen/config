#!/usr/bin/env bash

# Default settings (checked in)
export GHC_APP_EDITION_NODE=24
export GHC_APP_EDITION_NVIM=manual
export GHC_APP_EDITION_TMUX=latest
export GHC_APP_PYTHON_ENV=lemon
export GHC_EDITION=nix
export GHC_THEME=vsc-dark-modern

# Source local overrides if exists
[ -f "${BASH_SOURCE[0]%.sh}.local.sh" ] && source "${BASH_SOURCE[0]%.sh}.local.sh"
