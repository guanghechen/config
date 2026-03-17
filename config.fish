fish_vi_key_bindings

## Reset fish_user_paths (prevent duplication)
set -U fish_user_paths

## Setup bootstrap envs
set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx LANG en_US.UTF-8
set -gx LC_CTYPE en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -gx LESSCHARSET utf-8
set -gx TZ Asia/Shanghai
set -gx no_proxy "localhost,127.0.0.1,::1"

set -gx GHC_ENV_PLATFORM nix
if test (uname) = Darwin
    set -gx GHC_ENV_PLATFORM osx
else if test -r /proc/version; and grep -qEi "(Microsoft|WSL)" /proc/version
    set -gx GHC_ENV_PLATFORM wsl
else
    set -gx GHC_ENV_PLATFORM nix
end

## setup paths
set -gx CONDARC "$HOME/.config/conda/condarc"
set -gx LS_COLORS "di=1;94:ln=1;96:ex=1;92:or=1;91:mi=1;91:pi=93:so=1;95:bd=1;93:cd=1;93"
set -gx HOMEBREW_NO_ANALYTICS 1
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
if not set -q PREFER_NEOVIM_VERSION; or test "$PREFER_NEOVIM_VERSION" != stable
    if test -f "$HOME/.app/neovim/bin/nvim"
        set -gx NEOVIM_HOME "$HOME/.app/neovim"
    else if test -f /opt/me/app/neovim/bin/nvim
        set -gx NEOVIM_HOME /opt/me/app/neovim
    end
    fish_add_path --append "$NEOVIM_HOME/bin/" $PATH
end
fish_add_path --append /usr/local/bin/
fish_add_path --append "$HOMEBREW_PREFIX/bin/"
fish_add_path --append "$HOME/.local/bin/"

## setup environments
set -gx EDITOR "$NEOVIM_HOME/bin/nvim"
set -gx VISUAL "$NEOVIM_HOME/bin/nvim"
set -gx MYVIMRC "$HOME/.config/nvim/init.lua"
set -gx VIM "$NEOVIM_HOME/share/nvim"
set -gx VIMRUNTIME "$NEOVIM_HOME/share/nvim/runtime"
set -gx LG_CONFIG_FILE "$XDG_CONFIG_HOME/lazygit/config.yml,$XDG_CONFIG_HOME/lazygit/local/theme.yml"
set -gx NODE_OPTIONS "--max-old-space-size=8192"
set -gx PYTHONIOENCODING utf8
set -gx PYTHONPYCACHEPREFIX "$HOME/.cache/pycache"
set -gx PYTHONUTF8 1

### preference
set -x PREFER_NEOVIM_VERSION nightly
set -x PREFER_TMUX_VERSION stable
set -x ROOT_SOURCECODES "$HOME/sourcecodes"
set -x ROOT_WORKSPACE "$HOME/ws"
set -x YOZ_SERVER_PORT 7777

### agents
set -gx ANTHROPIC_BASE_URL 'http://127.0.0.1:4747/api/claude'
set -gx GOOGLE_GEMINI_BASE_URL 'http://127.0.0.1:4747/api/gemini'
set -gx OPENAI_BASE_URL 'http://127.0.0.1:4747/api/codex'

set -gx CLAUDE_CONFIG_DIR "$XDG_CONFIG_HOME/claude"
set -gx CODEX_HOME "$XDG_CONFIG_HOME/codex"
set -gx GEMINI_CONFIG_DIR "$HOME/.gemini"

set -gx ANTHROPIC_MODEL "claude-opus-4.6-1m"
set -gx ANTHROPIC_SMALL_FAST_MODEL "claude-sonnet-4.6"
set -gx CLAUDE_CODE_MAX_OUTPUT_TOKENS 64000

set -gx GEMINI_MODEL gemini-3-pro-preview

### local
if test -f "$HOME/.config/fish/local/env.fish"
    source "$HOME/.config/fish/local/env.fish"
end

## platform specific
if test "$GHC_ENV_PLATFORM" = osx
    source ~/.config/fish/conf/platform/mac/config.fish
else if test "$GHC_ENV_PLATFORM" = wsl
    source ~/.config/fish/conf/platform/wsl/config.fish
else
    source ~/.config/fish/conf/platform/nix/config.fish
end

source ~/.config/fish/conf/app.fish
source ~/.config/fish/conf/theme.fish
source ~/.config/fish/conf/alias.fish
source ~/.config/fish/conf/keymap.fish
