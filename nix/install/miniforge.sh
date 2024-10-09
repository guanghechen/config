#! /usr/bin/env bash

## Set environment variables
export PYTHONIOENCODING=utf8
export PYTHONUTF8=1
export HOME_MINIFORGE="$HOME/.app/miniforge3"

## Mkdirs
mkdir -p ~/.app/
mkdir -p ~/download/app/

## Download and install the miniforge3
cd ~/download/app/
curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
printf "\n\nyes\n$HOME_MINIFORGE\nyes\n" | bash Miniforge3-$(uname)-$(uname -m).sh # should install at ~/.app/miniforge3

export PATH=$HOME_MINIFORGE/bin:$PATH

### Setup conda
source "$HOME_MINIFORGE/etc/profile.d/conda.sh"
conda config --set auto_activate_base false
conda create --yes --name lemon python=3.12
conda activate lemon
pip install httpie ipython shell-gpt you-get

### Setup ipython
ipython profile create
echo -e "\nc.TerminalInteractiveShell.editing_mode = 'vi'" >>"$HOME/.ipython/profile_default/ipython_config.py"
