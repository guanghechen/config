#! /usr/bin/env bash

source "$HOME/.config/guanghechen/setup/nix/bot/env.bash"

## Set environment variables
printf "\e[96m  [setup miniforge] set environment variables...\e[0m\n"
export PYTHONIOENCODING=utf8
export PYTHONUTF8=1
export HOME_MINIFORGE="$HOME/.app/miniforge3"

if [ -d "$HOME_MINIFORGE" ]; then
  printf "\e[93m  [setup miniforge] miniforge is already installed. (skipped)\e[0m\n"
else
  miniforge_version="26.3.2-3"
  miniforge_system="$(uname)-$(uname -m)"
  case "$miniforge_system" in
    Linux-aarch64)
      miniforge_platform="Linux-aarch64"
      miniforge_sha256="2c113a69297e612b01ca0f320c22a3107a11f2ab9b573d79ac868a175945ce29"
      ;;
    Linux-ppc64le)
      miniforge_platform="Linux-ppc64le"
      miniforge_sha256="df7e80ee070ccc6031e2710eb4cf81ee0012264b587306b5aa3890d3d89edd97"
      ;;
    Linux-x86_64)
      miniforge_platform="Linux-x86_64"
      miniforge_sha256="848194851a98903134187fbb4ab50efe87b003e0c0f808f97644b7524a62bf2c"
      ;;
    Darwin-arm64)
      miniforge_platform="MacOSX-arm64"
      miniforge_sha256="59168f1e24d0a4ad9932021170809fca836cd240e183eeeb331d5bcfc0098168"
      ;;
    Darwin-x86_64)
      miniforge_platform="MacOSX-x86_64"
      miniforge_sha256="39273e4c89a0a1af4538010615d44ae8f44e1af41007e02def593d20f316b003"
      ;;
    *)
      printf "\e[91m [setup miniforge] unsupported platform: %s\e[0m\n" "$miniforge_system" >&2
      exit 1
      ;;
  esac
  miniforge_setup_sh="Miniforge3-${miniforge_version}-${miniforge_platform}.sh"
  miniforge_setup_url="https://github.com/conda-forge/miniforge/releases/download/${miniforge_version}/${miniforge_setup_sh}"

  ## Mkdirs
  mkdir -p ~/.app/
  mkdir -p ~/download/app/

  ## Download and install the miniforge3
  printf "\e[96m  [setup miniforge] downloading %s...\e[0m\n" "$miniforge_setup_sh"
  miniforge_setup_tmp="$(mktemp "$HOME/download/app/${miniforge_setup_sh}.XXXXXX")"
  trap 'rm -f "$miniforge_setup_tmp"' EXIT
  curl -fL "$miniforge_setup_url" -o "$miniforge_setup_tmp"

  if command -v sha256sum &>/dev/null; then
    miniforge_actual_sha256="$(sha256sum "$miniforge_setup_tmp" | awk '{print $1}')"
  elif command -v shasum &>/dev/null; then
    miniforge_actual_sha256="$(shasum -a 256 "$miniforge_setup_tmp" | awk '{print $1}')"
  else
    printf "\e[91m [setup miniforge] sha256sum or shasum is required.\e[0m\n" >&2
    exit 1
  fi
  if [ "$miniforge_actual_sha256" != "$miniforge_sha256" ]; then
    printf "\e[91m [setup miniforge] checksum mismatch for %s.\e[0m\n" "$miniforge_setup_sh" >&2
    exit 1
  fi

  printf "\e[96m  [setup miniforge] installing...\e[0m\n"
  bash "$miniforge_setup_tmp" -b -p "$HOME_MINIFORGE" -c
  rm -f "$miniforge_setup_tmp"
  trap - EXIT
fi
export PATH=$HOME_MINIFORGE/bin:$PATH

### Setup conda
printf "\e[96m  [setup miniforge] setting up conda...\e[0m\n"
source "$HOME_MINIFORGE/etc/profile.d/conda.sh"
conda config --set auto_activate_base false

if conda env list | grep -q "^lemon[[:space:]]"; then
  printf "\e[93m  [setup miniforge] the 'lemon' env is already created. (skipped)\e[0m\n"
else
  printf "\e[96m  [setup miniforge] creating 'lemon' env with conda...\e[0m\n"
  conda create --yes --name lemon python=3.12
  conda activate lemon
  pip install debugpy httpie ipython
fi

### Setup ipython
ipython_config_path="$HOME/.ipython/profile_default/ipython_config.py"
if [ -f "$ipython_config_path" ]; then
  printf "\e[93m  [setup miniforge] %s already exists. (skipped).\e[0m\n" "$ipython_config_path"
else
  printf "\e[96m  [setup miniforge] setting up ipython...\e[0m\n"
  conda run --name lemon ipython profile create
  printf "\nc.TerminalInteractiveShell.editing_mode = 'vi'\n" >>"$ipython_config_path"
fi
