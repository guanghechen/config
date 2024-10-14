### cargo
if test -f "$HOME/.cargo/bin/cargo"
  fish_add_path "$HOME/.cargo/bin"
end

### fnm
if type -q fnm
  fnm env --use-on-cd --shell fish | source
end

### miniforge3
if test -f "$HOME/.app/miniforge3/bin/conda"
  fish_add_path "$HOME/.app/miniforge3/bin"
  eval "$HOME/.app/miniforge3/bin/conda" "shell.fish" "hook" $argv | source
end

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
