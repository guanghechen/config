#!/usr/bin/env fish

# Default settings (checked in)
set -gx GHC_APP_EDITION_NODE '24'
set -gx GHC_APP_EDITION_NVIM 'manual'
set -gx GHC_APP_EDITION_TMUX 'latest'
set -gx GHC_APP_PYTHON_ENV 'lemon'
set -gx GHC_EDITION 'nix'
set -gx GHC_THEME 'vsc-dark-modern'

# Source local overrides if exists
set -l local_file (string replace '.fish' '.local.fish' (status filename))
test -f $local_file && source $local_file
