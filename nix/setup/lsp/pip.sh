#! /usr/bin/env bash

## @see https://mason-registry.dev/registry/list
source $HOME/.config/guanghechen/nix/setup/path.sh

pip install debugpy # [dap] python
pip install ruff    # [lint] python
pip install black   # [formatter] python
