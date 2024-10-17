Write-Host
Write-Host "[Setup config] starting..."

setx XDG_CONFIG_HOME    "$env:USERPROFILE\AppData\Local"
setx YAZI_FILE_ONE      "C:\app\git\usr\bin\file.exe"
setx YAZI_CONFIG_HOME   "$env:USERPROFILE\AppData\Local\yazi"

$config_root_dir = "$env:LOCALAPPDATA"
$config_repo_branch = @(
  "alacritty",
  "fzf",
  "helix",
  "lazygit",
  "lsd",
  "nvim",
  "ripgrep",
  "yazi"
)

# Function to clone or update a repository
function CloneOrUpdateRepo {
  param ([string]$branch)

  $repo_url = "https://github.com/guanghechen/config.git"
  $repo_path = Join-Path $config_root_dir $branch

  # Check if the directory exists
  if (Test-Path $repo_path) {
    Write-Host "Fetching $branch into $repo_path..."
    Set-Location -Path $repo_path
    git pull origin $branch
  } else {
    Write-Host "Cloning $branch into $repo_path..."
    Set-Location -Path $config_root_dir
    git clone $repo_url --single-branch --branch=$branch $repo_path
  }
}

# Loop through the repositories and clone or update each one
foreach ($branch in $config_repo_branch) {
  CloneOrUpdateRepo -branch $branch
}

Write-Host "[Setup config] done."
