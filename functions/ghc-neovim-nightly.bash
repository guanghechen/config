# shellcheck shell=bash
# ghc-neovim-nightly - Build and install Neovim nightly

ghc-neovim-nightly() {
    local neovim_source_dir
    neovim_source_dir=$(pwd -P) || return 1
    if [[ ! -f "$neovim_source_dir/src/nvim/main.c" ]]; then
        printf "\e[91m  Error: current directory is not a Neovim source tree\e[0m\n"
        return 1
    fi

    local default_neovim_install_dir="$HOME/.app/neovim"
    local neovim_install_dir="$default_neovim_install_dir"
    case "${NEOVIM_HOME:-}" in
        "")
            ;;
        "$default_neovim_install_dir"|/opt/me/app/neovim)
            neovim_install_dir="$NEOVIM_HOME"
            ;;
        *)
            printf "\e[91m  Error: NEOVIM_HOME is not an allowed nightly installation directory: %s\e[0m\n" "$NEOVIM_HOME" >&2
            printf "\e[91m  Unset it to use %s, or set it to /opt/me/app/neovim\e[0m\n" "$default_neovim_install_dir" >&2
            return 1
            ;;
    esac

    local ps_cmd="ps aux"
    if [[ "$GHC_ENV_PLATFORM" == "nix" || "$GHC_ENV_PLATFORM" == "wsl" ]]; then
        ps_cmd="ps -aux"
    fi

    local nvim_processes
    nvim_processes=$(eval "$ps_cmd" | grep nvim | grep -v grep)

    if [[ -n "$nvim_processes" ]]; then
        printf "\e[93m  Neovim processes are currently running:\e[0m\n\n"
        echo "$nvim_processes"
        printf "\n\e[91m  Please close all Neovim instances or kill the processes before continuing.\e[0m\n"
        local pids
        pids=$(echo "$nvim_processes" | awk '{print $2}' | tr '\n' ' ')
        printf "\e[96m  You can kill them with: kill %s\e[0m\n" "$pids"
        return 1
    fi

    local resolved_neovim_install_dir="$neovim_install_dir"
    if [[ -d "$neovim_install_dir" ]]; then
        resolved_neovim_install_dir=$(cd -P -- "$neovim_install_dir" && pwd) || return 1
    fi
    if [[ "$neovim_source_dir" == "$resolved_neovim_install_dir" || "$neovim_source_dir" == "$resolved_neovim_install_dir/"* ]]; then
        printf "\e[91m  Error: Neovim installation directory contains the source tree: %s\e[0m\n" "$neovim_install_dir"
        return 1
    fi

    printf "\e[94m  Building Neovim nightly for %s...\e[0m\n\n" "$neovim_install_dir"

    printf "\e[96m  Fetching and checking out the nightly tag...\e[0m\n"
    git fetch origin +refs/tags/nightly:refs/tags/nightly && git checkout --detach refs/tags/nightly || return 1

    printf "\n\e[96m  Building with CMake (RelWithDebInfo)...\e[0m\n"
    make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$neovim_install_dir" || return 1

    if [[ -e "$neovim_install_dir" || -L "$neovim_install_dir" ]]; then
        printf "\n\e[93m  Existing installation will be removed: %s\e[0m\n" "$neovim_install_dir"
        local confirmation
        read -r -p "Remove it and continue? [y/N] " confirmation
        confirmation=${confirmation,,}
        if [[ "$confirmation" != "y" && "$confirmation" != "yes" ]]; then
            printf "\e[91m  Installation cancelled\e[0m\n"
            return 1
        fi

        command rm -rf -- "$neovim_install_dir" || return 1
    fi

    printf "\n\e[96m  Installing to %s...\e[0m\n" "$neovim_install_dir"
    make install || return 1

    printf "\n\e[92m  Neovim nightly installed successfully!\e[0m\n"
}
