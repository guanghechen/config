[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Set-PSReadLineOption -EditMode Vi
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
. "$env:XDG_CONFIG_HOME\pwsh\alias.ps1"
. "$env:XDG_CONFIG_HOME\pwsh\functions\setup.ps1"

## Setup conda (lazy)
function conda {
  if (Test-Path "$env:APP_HOME_MINIFORGE\Scripts\conda.exe") {
    (& "$env:APP_HOME_MINIFORGE\Scripts\conda.exe" "shell.powershell" "hook") | Out-String | ?{$_} | Invoke-Expression
  }
  & conda @args
}

## Setup fnm (lazy)
function __fnm_init {
  if (-not $env:__FNM_INITIALIZED) {
    fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression
    $env:__FNM_INITIALIZED = "1"
  }
}
function node { __fnm_init; & node @args }
function npm { __fnm_init; & npm @args }
function npx { __fnm_init; & npx @args }
function pnpm { __fnm_init; & pnpm @args }

## Setup zoxide (lazy, need ensure executed at the last line. see https://github.com/ajeetdsouza/zoxide/issues/707#issuecomment-1959685345)
function __zoxide_init {
  if (-not $env:__ZOXIDE_INITIALIZED) {
    zoxide init powershell | Out-String | Invoke-Expression
    $env:__ZOXIDE_INITIALIZED = "1"
  }
}
function z { __zoxide_init; & z @args }
function zi { __zoxide_init; & zi @args }

