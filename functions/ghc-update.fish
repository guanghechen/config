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

    set required_configs btop conda fish fzf lazygit lsd nvim pm2 ripgrep tmux yazi yozora
    set optional_configs alacritty alacritty-windows claude ghostty helix kitty komorebi neovide nvim-lazy nvim-nvchad plan pwsh skhd tsuki wezterm yabai yasb

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
