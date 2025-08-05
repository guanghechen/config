### cargo
if test -f "$HOME/.cargo/bin/cargo"
    fish_add_path --prepend "$HOME/.cargo/bin/"
end

### fnm
if type -q fnm
    fnm env --use-on-cd --shell fish | source
end

## fzf
fzf_configure_bindings \
    --directory=\cf \
    --git_log=\cg \
    --git_status=\cs \
    --history=\co \
    --processes=\cp \
    --variables=\cv

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

### opencode
if test -f "$HOME/.opencode/bin/opencode"
    fish_add_path --prepend "$HOME/.opencode/bin/"
end

### tmux
if test -f "$ROOT_SOURCECODES/github/tmux/tmux/tmux"
    fish_add_path --prepend "$ROOT_SOURCECODES/github/tmux/tmux"
end

if test -n "$TMUX"
    set -x TERM tmux-256color
else
    set -x TERM xterm-256color
end

### yazi
set -gx FZF_DEFAULT_COMMAND "fd --type f"

### zoxide
if type -q zoxide
    zoxide init fish | source
end
