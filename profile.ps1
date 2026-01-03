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
. "$env:XDG_CONFIG_HOME\pwsh\app.ps1"
. "$env:XDG_CONFIG_HOME\pwsh\functions\setup.ps1"
