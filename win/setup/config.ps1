Write-Host "[setup config] preparing" -ForegroundColor Green

$config_root_dir = "$env:XDG_CONFIG_HOME"
$config_repo_branch = @(
  "fzf",
  "helix",
  "lazygit",
  "lsd",
  "nvim",
  "pwsh",
  "ripgrep",
  "yazi"
)
$optinal_config_repo_branch = @(
  "alacritty",
  "kitty",
  "nvim-nvchad"
)

# Function to clone or update a repository
function CloneOrUpdateRepo {
  param (
    [string]$branch,
    [bool]$required
  )

  $repo_url = "https://github.com/guanghechen/config.git"
  $repo_path = Join-Path $config_root_dir $branch
  $repo_path_git_dir = Join-Path $repo_path ".git"

  # Check if the directory exists
  if (Test-Path $repo_path_git_dir) {
    Write-Host "[setup config] fetching $branch into $repo_path..." -ForegroundColor Blue
    Set-Location -Path $repo_path
    git pull origin $branch
  } elseif ($required) {
    Write-Host "[setup config] cloning $branch into $repo_path..." -ForegroundColor Blue
    Set-Location -Path $config_root_dir
    git clone $repo_url --single-branch --branch=$branch $repo_path
  }
}

# Loop through the repositories and clone or update each one
foreach ($branch in $config_repo_branch) {
  CloneOrUpdateRepo -branch $branch $True
}
foreach ($branch in $config_repo_branch) {
  CloneOrUpdateRepo -branch $branch $False
}


# Define the source and destination paths
Write-Host "[setup config] copying pwsh profile.ps1..." -ForegroundColor Blue
$source = "$env:XDG_CONFIG_HOME\pwsh\profile.ps1"
Copy-Item -Path $source -Destination $PROFILE -Force

# Setup nvim
Write-Host "[setup config] setup nvim..." -ForegroundColor Blue
$nvim_repo_path = Join-Path $config_root_dir "nvim"
. "$nvim_repo_path/rust/nvim_tools/build.ps1"
nvim --headless -u "$nvim_repo_path/init-update.lua"

Write-Host "[setup config] done." -ForegroundColor Green
