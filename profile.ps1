[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Set-PSReadLineOption -EditMode Vi
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineKeyHandler -Chord Ctrl+y -Function AcceptSuggestion -ViMode Insert
Set-PSReadLineOption -Colors @{
  InlinePrediction        = "DarkGray"
  Command                 = "Yellow"
  Parameter               = "Cyan"
  Variable                = "Cyan"
  String                  = "Green"
  Default                 = "White"
}

$localEnvPath = "$env:XDG_CONFIG_HOME\pwsh\local\env.ps1"
if (Test-Path $localEnvPath) {
  . $localEnvPath
}

. "$env:XDG_CONFIG_HOME\pwsh\env.ps1"
. "$env:XDG_CONFIG_HOME\pwsh\app.ps1"

# Completions
Get-ChildItem "$env:XDG_CONFIG_HOME\pwsh\completions\*.ps1" | ForEach-Object { . $_.FullName }

## setup starship
if ([Environment]::GetEnvironmentVariable("STARSHIP_OS_ICON") -eq $null) {
  if ($env:OS -eq "Windows_NT") {
    $env:STARSHIP_OS_ICON = ""
  } elseif ($PSVersionTable.PSEdition -eq "Core" -and $IsMacOS) {
    $env:STARSHIP_OS_ICON = ""
  } else {
    $env:STARSHIP_OS_ICON = ""
  }
}

$env:STARSHIP_CONFIG = "$env:XDG_CONFIG_HOME\starship\pwsh.toml"
if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (&starship init powershell)
}

## Setup fnm
if (Get-Command fnm -ErrorAction SilentlyContinue) {
  fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression
}
