function ghc-update
    set reporoot "$HOME/.config"
    set repomain "$reporoot/guanghechen"

    if test -d "$repomain/.git"
        git -C $repomain fetch origin
        git -C $repomain merge origin/guanghechen --ff-only
    else
        git clone https://github.com/guanghechen/config.git --branch=guanghechen $repomain
    end

    #----------------------------------------------------------------------------------------------#

    set required_configs fish
    set optional_configs \
        alacritty \
        alacritty-windows \
        bat \
        btop \
        claude \
        conda \
        fzf \
        ghostty \
        git-delta \
        helix \
        kitty \
        komorebi \
        lazygit \
        lsd \
        neovide \
        nvim \
        nvim-lazy \
        nvim-nvchad \
        ora \
        plan \
        pm2 \
        pwsh \
        ripgrep \
        skhd \
        tmux \
        tsuki \
        wezterm \
        yabai \
        yasb \
        yazi \
        yoz

    for branch in $required_configs
        set repopath "$reporoot/$branch"
        if test -d "$repopath"
            printf "\e[94m  merging origin/$branch into $repopath\e[0m\n"
            set cmd "git -C '$repopath' merge origin/$branch --ff-only"
        else
            printf "\e[94m  add new worktree of $branch into $repopath\e[0m\n"
            set cmd "git -C '$repomain' worktree add '$repopath' $branch"
        end

        fish -c "$cmd"
        printf "\n"
    end

    for branch in $optional_configs
        set repopath "$reporoot/$branch"
        if test -d "$repopath"
            printf "\e[94m  merging origin/$branch into $repopath\e[0m\n"
            set cmd "git -C '$repopath' merge origin/$branch --ff-only"

            fish -c "$cmd"
            printf "\n"
        end
    end
end
