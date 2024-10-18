$env:APP_HOME_MINIFORGE = "C:\app\miniforge"
$env:APP_HOME_GIT       = "C:\app\git"
$env:XDG_CONFIG_HOME    = "$env:USERPROFILE\.config"
$env:XDG_DATA_HOME      = "$env:USERPROFILE\.local\share"
$env:XDG_STATE_HOME     = "$env:USERPROFILE\.local\state"
$env:YAZI_CONFIG_HOME   = "$env:XDG_CONFIG_HOME\yazi"
$env:YAZI_FILE_ONE      = "$env:APP_HOME_GIT\usr\bin\file.exe"

setx APP_HOME_MINIFORGE   "$env:APP_HOME_MINIFORGE"
setx APP_HOME_GIT         "$env:APP_HOME_GIT"
setx XDG_CONFIG_HOME      "$env:XDG_CONFIG_HOME"
setx XDG_DATA_HOME        "$env:XDG_DATA_HOME"
setx XDG_STATE_HOME       "$env:XDG_STATE_HOME"
setx YAZI_CONFIG_HOME     "$env:YAZI_CONFIG_HOME"
setx YAZI_FILE_ONE        "$env:YAZI_FILE_ONE"

# Define the local path and repositories
$config_root_dir = "$env:XDG_CONFIG_HOME"
$config_repo_path = Join-Path $config_root_dir "guanghechen"
if (Test-Path $config_repo_path) {
  Set-Location -Path $config_repo_path
  git pull origin "guanghechen"
} else {
  Set-Location -Path $config_root_dir
  git clone https://github.com/guanghechen/config.git --single-branch --branch=guanghechen $config_repo_path
}

Set-Location -Path $config_repo_path
. .\win\setup\config.ps1

Set-Location -Path $config_repo_path
. .\win\setup\winget.ps1

Set-Location -Path $config_repo_path
. .\win\setup\node.ps1

Set-Location -Path $config_repo_path
. .\win\setup\miniforge.ps1
