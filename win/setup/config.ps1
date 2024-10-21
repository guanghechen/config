function Write-ColoredMessage {
    param (
        [string]$Message,
        [string]$ColorCode
    )
    Write-Host "`n$Message" -ForegroundColor $ColorCode
}

Write-ColoredMessage "[setup config] preparing" Green

$config_root_dir = "$env:XDG_CONFIG_HOME"
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
    Write-ColoredMessage "[setup config] fetching $branch into $repo_path..." Blue
    Set-Location -Path $repo_path
    git pull origin $branch
  } else {
    Write-ColoredMessage "[setup config] cloning $branch into $repo_path..." Blue
    Set-Location -Path $config_root_dir
    git clone $repo_url --single-branch --branch=$branch $repo_path
  }
}

# Loop through the repositories and clone or update each one
foreach ($branch in $config_repo_branch) {
  CloneOrUpdateRepo -branch $branch
}

# Define the source and destination paths
Write-ColoredMessage "[setup config] copying pwsh profile.ps1..." Blue
$source = "$env:XDG_CONFIG_HOME\guanghechen\config\win\pwsh\profile.ps1"
$destination = $PROFILE
Copy-Item -Path $source -Destination $destination -Force

# Setup nvim
Write-ColoredMessage "[setup config] setup nvim..." Blue
$nvim_repo_path = Join-Path $config_root_dir "nvim"
Set-Location -Path $nvim_repo_path
. rust/nvim_tools/build.ps1

Write-ColoredMessage "[setup config] done." Green
