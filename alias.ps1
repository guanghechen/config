Set-Alias lg lazygit

function ll {
  lsd -l $args
}

function ccc {
  claude --dangerously-skip-permissions $args
}

