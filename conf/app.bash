# Application environment is shared by login and interactive shells.
# Interactive hooks run once per shell, including when config.bash is reloaded.

## starship (prompt)
# Respect an icon supplied by the environment; otherwise select a platform default.
if [[ -z "${STARSHIP_OS_ICON+x}" ]]; then
    if [[ "$GHC_ENV_PLATFORM" == "osx" ]]; then
        export STARSHIP_OS_ICON=""
    else
        export STARSHIP_OS_ICON=""
    fi
fi
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship/bash.toml"
if [[ $- == *i* && -z "${__BASH_CONF_APP_LOADED:-}" ]] && command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

## fnm
if [[ $- == *i* && -z "${__BASH_CONF_APP_LOADED:-}" ]] && command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell bash)"
fi

## bun
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    if [[ -x "$BUN_INSTALL/bin/bun" ]]; then
        [[ ":$PATH:" == *":$BUN_INSTALL/bin:"* ]] || export PATH="$PATH:$BUN_INSTALL/bin"
    fi
fi

## cargo
# Preserve inherited toolchain precedence when these entries already exist.
for _ghc_path in "${CARGO_HOME:-$HOME/.cargo}"/{bin,local/bin}; do
    [[ ":$PATH:" == *":$_ghc_path:"* ]] || export PATH="$_ghc_path:$PATH"
done
unset _ghc_path

## fzf (CSI u: Ctrl+Shift+Key)
# The corresponding Readline bindings live in conf/keymap.bash.
export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-fd --hidden --follow --no-ignore-vcs --color=never --exclude=.git --exclude=node_modules --exclude=.DS_Store --type=f}"
export FZF_DEFAULT_OPTS_FILE="${FZF_DEFAULT_OPTS_FILE:-$XDG_CONFIG_HOME/fzf/fzf.fzfrc}"

## miniforge3
if [[ $- == *i* && -z "${__BASH_CONF_APP_LOADED:-}" ]]; then
    _ghc_conda_root="$HOME/.app/miniforge3"
    _ghc_conda_exe="$_ghc_conda_root/bin/conda"
    _ghc_conda_hook="$_ghc_conda_root/etc/profile.d/conda.sh"
    if [[ -x "$_ghc_conda_exe" ]]; then
        export CONDA_CHANGEPS1=false
        export CONDA_PROMPT_MODIFIER=""

        # Avoid spawning Conda/Python unless the static hook is absent.
        if [[ -f "$_ghc_conda_hook" ]]; then
            source "$_ghc_conda_hook"
        elif __conda_setup="$("$_ghc_conda_exe" "shell.bash" "hook" 2>/dev/null)"; then
            eval "$__conda_setup"
        fi
        unset __conda_setup

        # Optional environment activation, kept disabled as in the Fish reference.
        # if [[ -n "${CONDA_PREFIX:-}" ]]; then
        #     _ghc_conda_env="${CONDA_PREFIX##*/}"
        #     conda activate base
        #     conda activate "$_ghc_conda_env"
        #     unset _ghc_conda_env
        # else
        #     conda activate base
        #     conda activate lemon
        # fi
    fi
    unset _ghc_conda_root _ghc_conda_exe _ghc_conda_hook
fi

## Application version paths
# Clear previous selections before applying preferences.
_ghc_path=":$PATH:"
for _ghc_dir in "$HOME/.app/neovim/bin" "/opt/me/app/neovim/bin" "$ROOT_SOURCECODES/github/tmux/tmux"; do
    while [[ "$_ghc_path" == *":$_ghc_dir:"* ]]; do
        _ghc_path="${_ghc_path/":$_ghc_dir:"/:}"
    done
done
_ghc_path="${_ghc_path#:}"
export PATH="${_ghc_path%:}"
unset _ghc_path _ghc_dir

## neovim
# Skip optional startup terminal queries that can wait or time out on slow terminals.
export NVIM_NOTTYFAST=1
# Only a detected standalone nightly installation takes precedence in PATH.
if [[ "$PREFER_NEOVIM_VERSION" != "stable" ]]; then
    if [[ -x "$HOME/.app/neovim/bin/nvim" ]]; then
        export NEOVIM_HOME="$HOME/.app/neovim"
        export PATH="$NEOVIM_HOME/bin:$PATH"
    elif [[ -x /opt/me/app/neovim/bin/nvim ]]; then
        export NEOVIM_HOME="/opt/me/app/neovim"
        export PATH="$NEOVIM_HOME/bin:$PATH"
    fi
fi
# Keep stable/custom installations available without moving existing PATH entries.
if [[ -n "${NEOVIM_HOME:-}" && -x "$NEOVIM_HOME/bin/nvim" ]]; then
    [[ ":$PATH:" == *":$NEOVIM_HOME/bin:"* ]] || export PATH="$PATH:$NEOVIM_HOME/bin"
    export EDITOR="$NEOVIM_HOME/bin/nvim"
    export VISUAL="$NEOVIM_HOME/bin/nvim"
    export SUDO_EDITOR="$NEOVIM_HOME/bin/nvim"
    export MYVIMRC="$XDG_CONFIG_HOME/nvim/init.lua"
    export VIM="$NEOVIM_HOME/share/nvim"
    export VIMRUNTIME="$NEOVIM_HOME/share/nvim/runtime"
fi

## tmux
# Prefer the source-built binary unless the stable version is explicitly requested.
if [[ "$PREFER_TMUX_VERSION" != "stable" && -x "$ROOT_SOURCECODES/github/tmux/tmux/tmux" ]]; then
    export PATH="$ROOT_SOURCECODES/github/tmux/tmux:$PATH"
fi
if [[ $- == *i* ]]; then
    if [[ -n "${TMUX:-}" ]]; then
        export TERM="tmux-256color"
    else
        export TERM="xterm-256color"
    fi
fi

## zoxide
if [[ $- == *i* && -z "${__BASH_CONF_APP_LOADED:-}" ]] && command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

if [[ $- == *i* ]]; then
    __BASH_CONF_APP_LOADED=1
fi
