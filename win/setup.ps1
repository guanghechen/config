# Define the local path and repositories
$config_root_dir = "$env:LOCALAPPDATA"
$config_repo_path = Join-Path $config_root_dir "guanghechen"
if (Test-Path $config_repo_path) {
  Set-Location -Path $config_repo_path
  git pull origin "guanghechen"
} else {
  Set-Location -Path $config_root_dir
  git clone https://github.com/guanghechen/config.git --single-branch --branch=guanghechen guanghechen
}

Set-Location -Path $config_repo_path
. .\win\setup\config.ps1

Set-Location -Path $config_repo_path
. .\win\setup\winget.ps1

Set-Location -Path $config_repo_path
. .\win\setup\miniforge.ps1
