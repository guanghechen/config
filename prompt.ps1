$env:STARSHIP_CONFIG = "$env:XDG_CONFIG_HOME\starship\pwsh.toml"
Invoke-Expression (&starship init powershell)
