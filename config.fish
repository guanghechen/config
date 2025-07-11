fish_vi_key_bindings

## Reset fish_user_paths (prevent duplication)
set -U fish_user_paths

## setup paths
set -gx CONDARC "$HOME/.config/conda/condarc"
if test -f /opt/homebrew/bin/brew
    set -gx HOMEBREW_PREFIX /opt/homebrew
    set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
    set -gx HOMEBREW_REPOSITORY /opt/homebrew
    set -gx HOMEBREW_SHELLENV_PREFIX /opt/homebrew
    set -gx NEOVIM_HOME /opt/homebrew
else if test -f /home/linuxbrew/.linuxbrew/bin/brew
    set -gx HOMEBREW_PREFIX "/home/linuxbrew/.linuxbrew"
    set -gx HOMEBREW_CELLAR "/home/linuxbrew/.linuxbrew/Cellar"
    set -gx HOMEBREW_REPOSITORY "/home/linuxbrew/.linuxbrew"
    set -gx HOMEBREW_SHELLENV_PREFIX "/home/linuxbrew/.linuxbrew"
    set -gx NEOVIM_HOME "/home/linuxbrew/.linuxbrew"
end
if not set -q PREFER_STABLE_NEOVIM; or test "$PREFER_STABLE_NEOVIM" != true
    if test -f "$HOME/.app/neovim/bin/nvim"
        set -gx NEOVIM_HOME "$HOME/.app/neovim"
    else if test -f /opt/me/app/neovim/bin/nvim
        set -gx NEOVIM_HOME /opt/me/app/neovim
    end
    fish_add_path "$NEOVIM_HOME/bin/" $PATH
end
fish_add_path /usr/local/bin/
fish_add_path "$HOMEBREW_PREFIX/bin/"
fish_add_path "$HOME/.local/bin/"

## setup environments
set -gx LC_CTYPE en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx LANG en_US.UTF-8
set -gx TZ Asia/Shanghai

set -gx XDG_CONFIG_HOME "$HOME/.config"

set -gx EDITOR "$NEOVIM_HOME/bin/nvim"
set -gx VISUAL "$NEOVIM_HOME/bin/nvim"
set -gx MYVIMRC "$HOME/.config/nvim/init.lua"
set -gx VIM "$NEOVIM_HOME/share/nvim"
set -gx VIMRUNTIME "$NEOVIM_HOME/share/nvim/runtime"

set -gx NODE_OPTIONS "--max-old-space-size=8192"

set -gx PYTHONIOENCODING utf8
set -gx PYTHONUTF8 1

set -gx no_proxy "localhost,127.0.0.1,::1"

## platform specific
if test (uname) = Darwin
    source ~/.config/fish/conf/platform/mac.fish
else if test -r /proc/version; and grep -qEi "(Microsoft|WSL)" /proc/version
    source ~/.config/fish/conf/platform/wsl.fish
else
    source ~/.config/fish/conf/platform/nix.fish
end
source ~/.config/fish/conf/platform/local.fish

source ~/.config/fish/conf/app.fish
source ~/.config/fish/conf/theme.fish
source ~/.config/fish/conf/fzf.fish
source ~/.config/fish/conf/alias.fish

complete -c ghc-theme-apply -a "catppuccin-latte catppuccin-mocha gruvbox-dark gruvbox-light nord one-half-dark one-half-light rose-pine-main rose-pine-moon rose-pine-dawn"
