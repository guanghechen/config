if test -f "$HOME/.app/miniforge3/bin/conda"
  fish_add_path "$HOME/.app/miniforge3/bin"
  eval "$HOME/.app/miniforge3/bin/conda" "shell.fish" "hook" $argv | source
end
