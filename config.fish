fish_vi_key_bindings

## Keep configured paths process-local
set -g fish_user_paths

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

### preference
set -gx PREFER_NEOVIM_VERSION stable
set -gx PREFER_TMUX_VERSION stable
set -gx ROOT_SOURCECODES "$HOME/sourcecodes"
set -gx ROOT_WORKSPACE "$HOME/ws"
set -gx YOZ_SERVER_PORT 7777

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
fish_add_path --append /usr/local/bin/
fish_add_path --append "$HOMEBREW_PREFIX/bin/"

## setup environments
set -gx LG_CONFIG_FILE "$XDG_CONFIG_HOME/lazygit/config.yml,$XDG_CONFIG_HOME/lazygit/local/theme.yml"
set -gx NODE_OPTIONS "--max-old-space-size=8192"
set -gx PYTHONIOENCODING utf8
set -gx PYTHONPYCACHEPREFIX "$HOME/.cache/pycache"
set -gx PYTHONUTF8 1

### agents
set -gx ANTHROPIC_BASE_URL 'http://127.0.0.1:4747/api/claude'
set -gx GOOGLE_GEMINI_BASE_URL 'http://127.0.0.1:4747/api/gemini'
set -gx OPENAI_BASE_URL 'http://127.0.0.1:4747/api/codex'

set -gx CLAUDE_CONFIG_DIR "$XDG_CONFIG_HOME/claude"
set -gx CODEX_HOME "$XDG_CONFIG_HOME/codex"
set -gx PI_CODING_AGENT_DIR "$XDG_CONFIG_HOME/pi"
set -gx PI_CODING_AGENT_SESSION_DIR "$HOME/.local/state/pi/sessions"
set -gx PI_TELEMETRY 0
set -gx GEMINI_CONFIG_DIR "$HOME/.gemini"

set -gx ANTHROPIC_MODEL "claude-opus-5[1m]"
set -gx ANTHROPIC_DEFAULT_HAIKU_MODEL claude-sonnet-5
set -gx CLAUDE_CODE_SUBAGENT_MODEL "claude-opus-5[1m]"

set -gx GEMINI_MODEL gemini-3-pro-preview

### local
if test -f "$HOME/.config/fish/local/env.fish"
    source "$HOME/.config/fish/local/env.fish"
end

## platform specific
if test "$GHC_ENV_PLATFORM" = osx
    source ~/.config/fish/conf/platform/osx/config.fish
else if test "$GHC_ENV_PLATFORM" = wsl
    source ~/.config/fish/conf/platform/wsl/config.fish
else
    source ~/.config/fish/conf/platform/nix/config.fish
end

source ~/.config/fish/conf/app.fish
source ~/.config/fish/conf/theme.fish
source ~/.config/fish/conf/alias.fish
source ~/.config/fish/conf/keymap.fish
