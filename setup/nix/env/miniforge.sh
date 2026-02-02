#! /usr/bin/env bash
# shellcheck disable=SC1091


# shellcheck source=setup/nix/path.sh
source "$HOME/.config/guanghechen/setup/nix/path.sh"

## Set environment variables
printf "\e[96m  [setup miniforge] set environment variables...\e[0m\n"
export PYTHONIOENCODING=utf8
export PYTHONUTF8=1
export HOME_MINIFORGE="$HOME/.app/miniforge3"

if [ -d "$HOME_MINIFORGE" ]; then
  printf "\e[93m  [setup miniforge] miniforge is already installed. (skipped)\e[0m\n"
else
  miniforge_setup_sh="Miniforge3-$(uname)-$(uname -m).sh"

  ## Mkdirs
  mkdir -p ~/.app/
  mkdir -p ~/download/app/
  cd "$HOME/download/app/" || return 1

  ## Download and install the miniforge3
  if [ -f "${miniforge_setup_sh}" ]; then
    printf "\e[93m  [setup miniforge] %s already exists. (skipped download)\e[0m\n" "$miniforge_setup_sh"
  else
    printf "\e[96m  [setup miniforge] downloading...\e[0m\n"
    curl -L -O "https://github.com/conda-forge/miniforge/releases/latest/download/${miniforge_setup_sh}"
  fi

  printf "\e[96m  [setup miniforge] installing...\e[0m\n"
  printf "\n\nyes\n%s\nyes\n" "$HOME_MINIFORGE" | bash "${miniforge_setup_sh}" # should install at ~/.app/miniforge3
fi
export PATH=$HOME_MINIFORGE/bin:$PATH

### Setup conda
printf "\e[96m  [setup miniforge] setting up conda...\e[0m\n"
# shellcheck source=/dev/null
source "$HOME_MINIFORGE/etc/profile.d/conda.sh"
conda config --set auto_activate_base false

if conda env list | grep -q "^lemon\s"; then
  printf "\e[93m  [setup miniforge] the 'lemon' env is already created. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup miniforge] creating 'lemon' env with conda...\e[0m\n"
  conda create --yes --name lemon python=3.12
  conda activate lemon
  pip install debugpy httpie ipython you-get
fi

### Setup ipython
ipython_config_path="$HOME/.ipython/profile_default/ipython_config.py"
if [ -f "$ipython_config_path" ]; then
  printf "\e[93m  [setup miniforge] %s already exists. (skipped).\e[0m\n" "$ipython_config_path"
else
  printf "\e[96m  [setup miniforge] setting up ipython...\e[0m\n"
  ipython profile create
  printf "\nc.TerminalInteractiveShell.editing_mode = 'vi'\n" >>"$ipython_config_path"
fi
