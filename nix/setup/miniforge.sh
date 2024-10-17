#! /usr/bin/env bash

## Set environment variables
printf "\n\e[34m  [setup miniforge] set environment variables...\e[0m\n"
export PYTHONIOENCODING=utf8
export PYTHONUTF8=1
export HOME_MINIFORGE="$HOME/.app/miniforge3"

if [ -d "$HOME_MINIFORGE" ]; then
  printf "\n\e[38;5;214m  [setup miniforge] miniforge is already installed. (skipped)\e[0m\n"
else
  ## Mkdirs
  mkdir -p ~/.app/
  mkdir -p ~/download/app/

  ## Download and install the miniforge3
  printf "\n\e[34m  [setup miniforge] downloading...\e[0m\n"
  cd ~/download/app/
  curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"

  printf "\n\e[34m  [setup miniforge] installing...\e[0m\n"
  printf "\n\nyes\n$HOME_MINIFORGE\nyes\n" | bash Miniforge3-$(uname)-$(uname -m).sh # should install at ~/.app/miniforge3
fi
export PATH=$HOME_MINIFORGE/bin:$PATH

### Setup conda
printf "\n\e[34m  [setup miniforge] setting up conda...\e[0m\n"
source "$HOME_MINIFORGE/etc/profile.d/conda.sh"
conda config --set auto_activate_base false

if conda env list | grep -q "^lemon\s"; then
  printf "\n\e[38;5;214m  [setup miniforge] the 'lemon' env is already created. (skipped)\e[0m\n"
else
  printf "\n\e[34m  [setup miniforge] creating 'lemon' env with conda...\e[0m\n"
  conda create --yes --name lemon python=3.12
fi

conda activate lemon
pip install ipython shell-gpt

### Setup ipython
ipython_config_path="$HOME/.ipython/profile_default/ipython_config.py"
if [ -f $ipython_config_path ]; then
  printf "\n\e[38;5;214m  [setup miniforge] $ipython_config_path is already exist. (skipped).\e[0m\n"
else
  printf "\n\e[34m  [setup miniforge] setting up ipython...\e[0m\n"
  ipython profile create
  printf "\nc.TerminalInteractiveShell.editing_mode = 'vi'\n" >>"$ipython_config_path"
fi
