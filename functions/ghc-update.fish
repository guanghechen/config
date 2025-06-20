function ghc-update
    set required_configs btop conda fish fzf guanghechen lazygit lsd nvim pm2 ripgrep tmux yazi yozora
    set optional_configs alacritty alacritty-windows ghostty helix kitty neovide nvim-nvchad plan pwsh shell_gpt tsuki wezterm
    set base_path "$HOME/.config"

    for config in $required_configs
        set dir "$base_path/$config"
        if test -d "$dir"
            set cmd "cd $dir && git pull origin $config"
        else
            set cmd "git clone https://github.com/guanghechen/config.git --single-branch --branch=$config $dir"
        end

        set_color white
        printf "\n%s\n" $cmd

        set_color normal
        fish -c "$cmd"
    end

    for config in $optional_configs
        set dir "$base_path/$config"
        if test -d "$dir"
            set cmd "cd $dir && git pull origin $config"

            set_color white
            printf "\n%s\n" $cmd

            set_color normal
            fish -c "$cmd"
        end
    end
end
