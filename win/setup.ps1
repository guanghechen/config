setx XDG_CONFIG_HOME    "$env:USERPROFILE\.config"
setx YAZI_CONFIG_HOME   "$env:XDG_CONFIG_HOME\yazi"
setx YAZI_FILE_ONE      "C:\app\git\usr\bin\file.exe"

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
