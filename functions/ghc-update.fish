function ghc-update
  set required_configs btop conda fish fzf guanghechen lazygit lsd nvim pm2 ripgrep tmux yazi yozora
  set optional_configs alacritty alacritty-windows claude ghostty helix kitty neovide nvim-nvchad opencode plan pwsh tsuki wezterm
  set reporoot "$HOME/.config"

  for branch in $required_configs
    set repopath "$reporoot/$branch"
    if test -d "$repopath"
      printf "\e[34mfetching $branch into $repopath\e[0m\n"
      set cmd "git -C $repopath pull origin $branch"
    else
      printf "\e[34mcloning $branch into $repopath\e[0m\n"
      set cmd "git clone https://github.com/guanghechen/config.git --single-branch --branch=$branch $repopath"
    end

    fish -c "$cmd"
    printf "\n"
  end

  for branch in $optional_configs
    set repopath "$reporoot/$branch"
    if test -d "$repopath"
      printf "\e[34mfetching $branch into $repopath\e[0m\n"
      set cmd "git -C $repopath pull origin $branch"

      fish -c "$cmd"
      printf "\n"
    end
  end
end
