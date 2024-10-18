function Write-ColoredMessage {
    param (
        [string]$Message,
        [string]$ColorCode
    )
    Write-Host "`n$Message" -ForegroundColor $ColorCode
}

Write-ColoredMessage "[setup winget] preparing..." Green

winget install -e --source winget --id Microsoft.WindowsTerminal.Preview
winget install -e --source winget --id Microsoft.PowerShell
winget install -e --source winget --id JesseDuffield.lazygit
winget install -e --source winget --id Neovim.Neovim
winget install -e --source winget --id sharkdp.fd
winget install -e --source winget --id Schniz.fnm
winget install -e --source winget --id junegunn.fzf
winget install -e --source winget --id BurntSushi.ripgrep.MSVC
winget install -e --source winget --id jqlang.jq
winget install -e --source winget --id dandavison.delta
winget install -e --source winget --id JanDeDobbeleer.OhMyPosh
winget install -e --source winget --id lsd-rs.lsd
winget install -e --source winget --id ajeetdsouza.zoxide
winget install -e --source winget --id sxyazi.yazi
winget install -e --source winget --id ImageMagick.ImageMagick

Write-ColoredMessage "[setup winget] done." Green
