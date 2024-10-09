function ghc-refresh-configs
  set primary_configs alacritty btop fish fzf helix lazygit nvim ripgrep tmux
  set develop_configs guanghechen nvim-nvchad
  set base_path "$HOME/.config"

  for config in $primary_configs
    set dir "$base_path/$config"
    if test -d "$dir"
      set cmd "cd $dir && git pull origin $config"
    else
      set cmd "git clone https://github.com/guanghechen/config.git --single-branch --branch=$config $dir"
    end

    set_color $fish_color_gray
    printf "\n%s\n" $cmd

    set_color normal
    fish -c "$cmd"
  end

  for config in $develop_configs
    set dir "$base_path/$config"
    if test -d "$dir"
      set cmd "cd $dir && git pull origin $config"

      set_color $fish_color_gray
      printf "\n%s\n" $cmd

      set_color normal
      fish -c "$cmd"
    end
  end
end

