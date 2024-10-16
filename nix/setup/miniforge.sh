#! /usr/bin/env bash

## Set environment variables
echo -e "\e[34m  [setup miniforge] set environment variables...\e[0m"
export PYTHONIOENCODING=utf8
export PYTHONUTF8=1
export HOME_MINIFORGE="$HOME/.app/miniforge3"

## Mkdirs
mkdir -p ~/.app/
mkdir -p ~/download/app/

## Download and install the miniforge3
echo -e "\n\e[34m  [setup miniforge] downloading...\e[0m"
cd ~/download/app/
curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"

echo -e "\n\e[34m  [setup miniforge] installing...\e[0m"
printf "\n\nyes\n$HOME_MINIFORGE\nyes\n" | bash Miniforge3-$(uname)-$(uname -m).sh # should install at ~/.app/miniforge3
export PATH=$HOME_MINIFORGE/bin:$PATH

### Setup conda
echo -e "\n\e[34m  [setup miniforge] setting up conda...\e[0m"
source "$HOME_MINIFORGE/etc/profile.d/conda.sh"
conda config --set auto_activate_base false
conda create --yes --name lemon python=3.12
conda activate lemon
pip install ipython shell-gpt

### Setup ipython
echo -e "\n\e[34m  [setup miniforge] setting up ipython...\e[0m"
ipython profile create
echo -e "\nc.TerminalInteractiveShell.editing_mode = 'vi'" >>"$HOME/.ipython/profile_default/ipython_config.py"

echo -e "\e[32m  [setup miniforge] done.\e[0m"
