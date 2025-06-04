### cargo
if test -f "$HOME/.cargo/bin/cargo"
  fish_add_path "$HOME/.cargo/bin/"
end

### fnm
if type -q fnm
  fnm env --use-on-cd --shell fish | source
end

### miniforge3
if test -f "$HOME/.app/miniforge3/bin/conda"
  fish_add_path "$HOME/.app/miniforge3/bin/conda"
  set -gx CONDA_CHANGEPS1 false
  set -gx CONDA_PROMPT_MODIFIER ""
  eval "$HOME/.app/miniforge3/bin/conda" "shell.fish" "hook" $argv | source

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
if not set -q PREFER_STABLE_NEOVIM; or test "$PREFER_STABLE_NEOVIM" != "true"
  if test -f "$HOME/.app/neovim/bin/nvim"
    set -gx NEOVIM_HOME                   "$HOME/.app/neovim"
  else if test -f "/opt/me/app/neovim/bin/nvim"
    set -gx NEOVIM_HOME                   "/opt/me/app/neovim"
  end
end
set -gx VIM                             "$NEOVIM_HOME/share/nvim"
set -gx VIMRUNTIME                      "$NEOVIM_HOME/share/nvim/runtime"
fish_add_path "$NEOVIM_HOME/bin/" $PATH

### tmux
if test -n "$TMUX"
  set -x TERM tmux-256color
else
  set -x TERM xterm-256color
end

### zoxide
if type -q zoxide
  zoxide init fish | source
end
