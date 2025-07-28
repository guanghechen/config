$env:APP_HOME_MINIFORGE   = "C:\app\miniforge"
$env:APP_HOME_GIT         = "C:\app\git"
$env:XDG_CONFIG_HOME      = "$env:USERPROFILE\.config"
$env:XDG_DATA_HOME        = "$env:USERPROFILE\.local\share"
$env:XDG_STATE_HOME       = "$env:USERPROFILE\.local\state"
$env:CLAUDE_CONFIG_DIR    = "$env:XDG_CONFIG_HOME\claude"
$env:KOMOREBI_CONFIG_HOME = "$env:XDG_CONFIG_HOME\komorebi"
$env:LG_CONFIG_FILE       = "$env:XDG_CONFIG_HOME\lazygit\config.yml,$env:XDG_CONFIG_HOME\lazygit\local\theme.yml"
$env:NODE_OPTIONS         = "--max-old-space-size=8192"
$env:PYTHONIOENCODING     = "utf8"
$env:PYTHONUTF8           = 1
$env:YAZI_CONFIG_HOME     = "$env:XDG_CONFIG_HOME\yazi"
$env:YAZI_FILE_ONE        = "$env:APP_HOME_GIT\usr\bin\file.exe"

setx APP_HOME_MINIFORGE   "$env:APP_HOME_MINIFORGE"
setx APP_HOME_GIT         "$env:APP_HOME_GIT"
setx XDG_CONFIG_HOME      "$env:XDG_CONFIG_HOME"
setx XDG_DATA_HOME        "$env:XDG_DATA_HOME"
setx XDG_STATE_HOME       "$env:XDG_STATE_HOME"
setx CLAUDE_CONFIG_DIR    "$env:CLAUDE_CONFIG_DIR"
setx KOMOREBI_CONFIG_HOME "$env:KOMOREBI_CONFIG_HOME"
setx LG_CONFIG_FILE       "$env:LG_CONFIG_FILE"
setx NODE_OPTIONS         "$env:NODE_OPTIONS"
setx PYTHONIOENCODING     "$env:PYTHONIOENCODING"
setx PYTHONUTF8           $env:PYTHONUTF8
setx YAZI_CONFIG_HOME     "$env:YAZI_CONFIG_HOME"
setx YAZI_FILE_ONE        "$env:YAZI_FILE_ONE"

# Define the local path and repositories
$reporoot = "$env:XDG_CONFIG_HOME"
$repomain = Join-Path $reporoot "guanghechen"
if (Test-Path $repomain) {
  git -C "$repomain" fetch origin
  git -C "$repomain" merge origin/guanghechen --ff-only
} else {
  git -C "$reporoot" clone https://github.com/guanghechen/config.git --branch=guanghechen $repomain
}

Set-Location -Path $repomain
. .\win\setup\config.ps1

Set-Location -Path $repomain
. .\win\setup\winget.ps1

Set-Location -Path $repomain
. .\win\setup\node.ps1

Set-Location -Path $repomain
. .\win\setup\miniforge.ps1

Set-Location -Path $repomain
. .\win\setup\theme.ps1

