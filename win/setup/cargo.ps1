Write-Host "  [setup argo] preparing..." -ForegroundColor Green

cargo install tree-sitter-cli

## Cargo version is updated too frequently and sometimes could build failed.
# cargo install --locked git-delta
# cargo install --locked fd-find
# cargo install --locked fnm
# cargo install --locked lsd
# cargo install --locked ripgrep
# cargo install --locked yazi-fm yazi-cli
# cargo install --locked zoxide

Write-Host "  [setup cargo] done." -ForegroundColor Green
