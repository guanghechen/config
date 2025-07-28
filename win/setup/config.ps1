Write-Host "[setup config] preparing" -ForegroundColor DarkGreen

$reporoot = "$env:XDG_CONFIG_HOME"
$repomain = Join-Path $reporoot guanghechen
$repo_required_branches = @(
  "conda",
  "fzf",
  "lazygit",
  "nvim",
  "pwsh",
  "ripgrep",
  "yazi"
)
$repo_optional_branches = @(
  "alacritty",
  "alacritty-windows",
  "btop",
  "claude",
  "fish",
  "ghostty",
  "helix",
  "kitty",
  "komorebi",
  "lsd",
  "neovide",
  "nvim-lazy",
  "nvim-nvchad",
  "plan",
  "pm2",
  "skhd",
  "tsuki",
  "wezterm",
  "yabai",
  "yasb",
  "yozora"
)

foreach ($branch in $repo_required_branches) {
  $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
  if (Test-Path -Path $repopath) {
    Write-Host "[setup config] merging origin/$branch into $repopath..." -ForegroundColor DarkBlue
    $cmd = "git -C '$repopath' merge origin/$branch --ff-only"
  } else {
    Write-Host "[setup config] add new worktree of $branch into $repopath..." -ForegroundColor DarkBlue
    $cmd = "git -C '$repomain' worktree add '$repopath' $branch"
  }
  Invoke-Expression $cmd
  Write-Host
}

foreach ($branch in $repo_optional_branches) {
  $repopath = Join-Path $env:XDG_CONFIG_HOME $branch
  if (Test-Path -Path $repopath) {
    Write-Host "[setup config] merging origin/$branch into $repopath..." -ForegroundColor DarkBlue
    $cmd = "git -C '$repopath' merge origin/$branch --ff-only"
    Invoke-Expression $cmd
    Write-Host
  }
}

# Define the source and destination paths
Write-Host "[setup config] copying pwsh profile.ps1..." -ForegroundColor DarkBlue
$source = "$env:XDG_CONFIG_HOME\pwsh\profile.ps1"
Copy-Item -Path $source -Destination $PROFILE -Force

# Setup nvim
Write-Host "[setup config] setup nvim..." -ForegroundColor DarkBlue
$nvim_repopath = Join-Path $reporoot "nvim"
. "$nvim_repopath/rust/nvim_tools/build.ps1"
nvim --headless -u "$nvim_repopath/init-update.lua"

# Setup rust

$cargo_config_path = Join-Path "$env:USERPROFILE" ".cargo\\config.toml"
if (Test-Path $cargo_config_path) {
  Write-Host "[setup config] cargo config already exists. (skipped)" -ForegroundColor DarkYellow
} else {
  Write-Host "[setup config] copying cargo.toml..." -ForegroundColor DarkBlue
  $source = Join-Path $reporoot "guanghechen\\config\\cargo.toml"
  $target = $cargo_config_path
  Copy-Item -Path $source -Destination $target -Force
}

Write-Host "[setup config] done." -ForegroundColor DarkGreen
