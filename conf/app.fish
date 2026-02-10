### starship (prompt)
set -gx STARSHIP_CONFIG "$HOME/.config/starship/fish.toml"
if type -q starship
    starship init fish | source
end

### bun
if test -d "$HOME/.bun"
    set -gx BUN_INSTALL "$HOME/.bun"
    fish_add_path --prepend "$BUN_INSTALL/bin"
end

### cargo
if test -f "$HOME/.cargo/bin/cargo"
    fish_add_path --prepend "$HOME/.cargo/bin/"
end

### fnm
if type -q fnm
    fnm env --use-on-cd --shell fish | source
end

## fzf (CSI u: Ctrl+Shift+Key)
set -gx FZF_DEFAULT_COMMAND "fd --hidden --follow --no-ignore-vcs --color=never --exclude=.git --exclude=node_modules --exclude=.DS_Store --type=f"
set -gx FZF_DEFAULT_OPTS_FILE "$HOME/.config/fzf/fzf.fzfrc"

### miniforge3
if test -f "$HOME/.app/miniforge3/bin/conda"
    fish_add_path --prepend "$HOME/.app/miniforge3/bin/conda"
    set -gx CONDA_CHANGEPS1 false
    set -gx CONDA_PROMPT_MODIFIER ""
    eval "$HOME/.app/miniforge3/bin/conda" "shell.fish" hook $argv | source

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
