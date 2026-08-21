### starship (prompt)
if not set -q STARSHIP_OS_ICON
    if test "$GHC_ENV_PLATFORM" = osx
        set -gx STARSHIP_OS_ICON ''
    else
        set -gx STARSHIP_OS_ICON ''
    end
end

set -gx STARSHIP_CONFIG "$HOME/.config/starship/fish.toml"
if type -q starship
    starship init fish | source
end

### fnm
if type -q fnm
    fnm env --use-on-cd --shell fish | source
end

### bun
if test -d "$HOME/.bun"
    set -gx BUN_INSTALL "$HOME/.bun"
    fish_add_path --append "$BUN_INSTALL/bin"
end

### cargo
set -l cargo_home "$HOME/.cargo"
if set -q CARGO_HOME; and test -n "$CARGO_HOME"
    set cargo_home "$CARGO_HOME"
end
fish_add_path --path --prepend --move \
    "$cargo_home/local/bin" \
    "$cargo_home/bin"

### flutter
if test -f "$ROOT_SOURCECODES/github/flutter/flutter/bin/flutter"
    fish_add_path --prepend "$ROOT_SOURCECODES/github/flutter/flutter/bin"
end

## fzf (CSI u: Ctrl+Shift+Key)
set -gx FZF_DEFAULT_COMMAND "fd --hidden --follow --no-ignore-vcs --color=never --exclude=.git --exclude=node_modules --exclude=.DS_Store --type=f"
set -gx FZF_DEFAULT_OPTS_FILE "$HOME/.config/fzf/fzf.fzfrc"

### miniforge3
set -l conda_exe "$HOME/.app/miniforge3/bin/conda"
if test -x "$conda_exe"
    set -gx CONDA_CHANGEPS1 false
    set -gx CONDA_PROMPT_MODIFIER ""
    "$conda_exe" shell.fish hook | source

    # if status is-interactive
    #   if set -q CONDA_PREFIX
    #     set conda_env (basename "$CONDA_PREFIX")
    #     conda activate base
    #     conda activate $conda_env
    #   else
    #     conda activate base
    #     conda activate lemon
    #   end
    # end
end

### neovim
if test "$PREFER_NEOVIM_VERSION" != stable
    if test -x "$HOME/.app/neovim/bin/nvim"
        set -gx NEOVIM_HOME "$HOME/.app/neovim"
    else if test -x /opt/me/app/neovim/bin/nvim
        set -gx NEOVIM_HOME /opt/me/app/neovim
    end

    if set -q NEOVIM_HOME
        fish_add_path --prepend --move "$NEOVIM_HOME/bin/"
    end
end
if set -q NEOVIM_HOME; and test -x "$NEOVIM_HOME/bin/nvim"
    set -gx EDITOR "$NEOVIM_HOME/bin/nvim"
    set -gx VISUAL "$NEOVIM_HOME/bin/nvim"
    set -gx MYVIMRC "$HOME/.config/nvim/init.lua"
    set -gx VIM "$NEOVIM_HOME/share/nvim"
    set -gx VIMRUNTIME "$NEOVIM_HOME/share/nvim/runtime"
end

# ollama
set -gx OLLAMA_NO_CLOUD 1
set -gx OLLAMA_NOHISTORY 1
set -gx OLLAMA_DEBUG_LOG_REQUESTS 0

### pnpm
set -gx PNPM_HOME "$HOME/Library/pnpm"
if not string match -q -- "$PNPM_HOME/bin" $PATH
    set -gx PATH "$PNPM_HOME/bin" $PATH
end

### tmux
if not set -q PREFER_TMUX_VERSION; or test "$PREFER_TMUX_VERSION" != stable
    if test -f "$ROOT_SOURCECODES/github/tmux/tmux/tmux"
        fish_add_path --prepend "$ROOT_SOURCECODES/github/tmux/tmux"
    end
end

if test -n "$TMUX"
    set -x TERM tmux-256color
else
    set -x TERM xterm-256color
end

### zoxide
if type -q zoxide
    zoxide init fish | source
end

### local
fish_add_path --append "$HOME/.local/bin/"
