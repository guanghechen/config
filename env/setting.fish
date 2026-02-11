#!/usr/bin/env fish

# Default settings (checked in)
set -gx GHC_APP_EDITION_NODE '24'
set -gx GHC_APP_EDITION_NVIM 'manual'
set -gx GHC_APP_EDITION_TMUX 'latest'
set -gx GHC_APP_PYTHON_ENV 'lemon'
set -gx GHC_EDITION 'nix'
set -gx GHC_THEME 'vsc-dark-modern'

# Source local overrides if exists
set -l _ghc_env_dir (dirname (status filename))
test -f "$_ghc_env_dir/setting.local.fish" && source "$_ghc_env_dir/setting.local.fish"
