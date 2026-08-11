function ghc-neovim-nightly
    set -l neovim_source_dir (path resolve .)
    if not test -f "$neovim_source_dir/src/nvim/main.c"
        printf "\e[91m Error: current directory is not a Neovim source tree\e[0m\n"
        return 1
    end

    set -l ps_cmd "ps aux"
    if test "$GHC_ENV_PLATFORM" = nix; or test "$GHC_ENV_PLATFORM" = wsl
        set ps_cmd "ps -aux"
    end

    set -l nvim_processes (eval $ps_cmd | grep nvim | grep -v grep)

    if test -n "$nvim_processes"
        printf "\e[93m  Neovim processes are currently running:\e[0m\n\n"
        echo "$nvim_processes"
        printf "\n\e[91m  Please close all Neovim instances or kill the processes before continuing.\e[0m\n"
        set -l pids (echo "$nvim_processes" | awk '{print $2}' | string join ' ')
        printf "\e[96m  You can kill them with: kill %s\e[0m\n" "$pids"
        return 1
    end

    set -l default_neovim_install_dir (path normalize "$HOME/.app/neovim")
    set -l neovim_install_dir "$default_neovim_install_dir"
    if set -q NEOVIM_HOME
        if test (count $NEOVIM_HOME) -ne 1; or test -z "$NEOVIM_HOME"
            printf "\e[91m  Error: NEOVIM_HOME must contain exactly one non-empty path\e[0m\n"
            return 1
        end

        set -l configured_neovim_home (path normalize "$NEOVIM_HOME")
        if contains -- "$configured_neovim_home" "$default_neovim_install_dir" /opt/me/app/neovim
            set neovim_install_dir "$configured_neovim_home"
        end
    end

    set -l resolved_neovim_install_dir (path resolve "$neovim_install_dir")
    set -l install_dir_pattern '^'(string escape --style=regex "$resolved_neovim_install_dir")'(/|$)'
    if string match --quiet --regex -- "$install_dir_pattern" "$neovim_source_dir"
        printf "\e[91m  Error: Neovim installation directory contains the source tree: %s\e[0m\n" "$neovim_install_dir"
        return 1
    end

    printf "\e[94m  Building Neovim nightly for %s...\e[0m\n\n" "$neovim_install_dir"

    printf "\e[96m  Fetching and checking out the nightly tag...\e[0m\n"
    git fetch origin +refs/tags/nightly:refs/tags/nightly && git checkout --detach refs/tags/nightly; or return 1

    printf "\n\e[96m  Building with CMake (RelWithDebInfo)...\e[0m\n"
    make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX="$neovim_install_dir"; or return 1

    if test -e "$neovim_install_dir"; or test -L "$neovim_install_dir"
        printf "\n\e[93m  Existing installation will be removed: %s\e[0m\n" "$neovim_install_dir"
        read --local --prompt-str "Remove it and continue? [y/N] " confirmation
        set confirmation (string lower -- "$confirmation")
        if not contains -- "$confirmation" y yes
            printf "\e[91m  Installation cancelled\e[0m\n"
            return 1
        end

        command rm -rf -- "$neovim_install_dir"; or return 1
    end

    printf "\n\e[96m  Installing to %s...\e[0m\n" "$neovim_install_dir"
    make install; or return 1

    printf "\n\e[92m  Neovim nightly installed successfully!\e[0m\n"
end
