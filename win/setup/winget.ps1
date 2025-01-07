Write-Host "[setup winget] preparing..." -ForegroundColor Green

winget install -e --source winget --id Microsoft.WindowsTerminal.Preview
winget install -e --source winget --id Microsoft.PowerShell
winget install -e --source winget --id Microsoft.PowerToys
winget install -e --source winget --id Neovim.Neovim

# winget install -e --source winget --id dandavison.delta
# winget install -e --source winget --id sharkdp.fd
# winget install -e --source winget --id Schniz.fnm
winget install -e --source winget --id ImageMagick.ImageMagick
winget install -e --source winget --id junegunn.fzf
winget install -e --source winget --id jqlang.jq
winget install -e --source winget --id JesseDuffield.lazygit
# winget install -e --source winget --id lsd-rs.lsd
# winget install -e --source winget --id BurntSushi.ripgrep.MSVC
# winget install -e --source winget --id sxyazi.yazi
# winget install -e --source winget --id ajeetdsouza.zoxide


cargo install --locked git-delta
cargo install --locked fd-find
cargo install --locked fnm
cargo install --locked lsd
cargo install --locked ripgrep
cargo install --locked yazi-fm yazi-cli
cargo install --locked zoxide

Write-Host "[setup winget] done." -ForegroundColor Green
