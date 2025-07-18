Write-Host "[setup config] preparing" -ForegroundColor DarkGreen

$config_root_dir = "$env:XDG_CONFIG_HOME"
$config_repo_branch = @(
  "conda",
  "fzf",
  "lazygit",
  "nvim",
  "pwsh",
  "ripgrep",
  "yazi"
)
$optinal_config_repo_branch = @(
  "alacritty",
  "alacritty-windows",
  "btop",
  "claude",
  "fish",
  "ghostty",
  "helix",
  "kitty",
  "lsd",
  "neovide",
  "nvim-nvchad",
  "opencode",
  "plan",
  "pm2",
  "tsuki",
  "wezterm",
  "yozora"
)

foreach ($branch in $config_repo_branch) {
  $dir = Join-Path $env:XDG_CONFIG_HOME $branch
  if (Test-Path -Path $dir) {
    Write-Host "[setup config] fetching $branch into $dir..." -ForegroundColor DarkBlue
    $cmd = "git -C '$dir' pull origin $branch"
  } else {
    Write-Host "[setup config] cloning $branch into $dir..." -ForegroundColor DarkBlue
    $cmd = "git clone https://github.com/guanghechen/config.git --single-branch --branch=$branch '$dir'"
  }
  Invoke-Expression $cmd
}

foreach ($branch in $optinal_config_repo_branch) {
  $dir = Join-Path $env:XDG_CONFIG_HOME $branch
  if (Test-Path -Path $dir) {
    Write-Host "[setup config] fetching $branch into $dir..." -ForegroundColor DarkBlue
    $cmd = "git -C '$dir' pull origin $branch"
    Invoke-Expression $cmd
  }
}

# Define the source and destination paths
Write-Host "[setup config] copying pwsh profile.ps1..." -ForegroundColor DarkBlue
$source = "$env:XDG_CONFIG_HOME\pwsh\profile.ps1"
Copy-Item -Path $source -Destination $PROFILE -Force

# Setup nvim
Write-Host "[setup config] setup nvim..." -ForegroundColor DarkBlue
$nvim_repo_path = Join-Path $config_root_dir "nvim"
. "$nvim_repo_path/rust/nvim_tools/build.ps1"
nvim --headless -u "$nvim_repo_path/init-update.lua"

# Setup rust

$cargo_config_path = Join-Path "$env:USERPROFILE" ".cargo\\config.toml"
if (Test-Path $cargo_config_path) {
  Write-Host "[setup config] cargo config already exists. (skipped)" -ForegroundColor DarkYellow
} else {
  Write-Host "[setup config] copying cargo.toml..." -ForegroundColor DarkBlue
  $source = Join-Path $config_root_dir "guanghechen\\config\\cargo.toml"
  $target = $cargo_config_path
  Copy-Item -Path $source -Destination $target -Force
}

Write-Host "[setup config] done." -ForegroundColor DarkGreen
